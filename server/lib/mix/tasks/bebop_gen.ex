# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Mix.Tasks.Bebop.Generate — Bebop codegen from .bop schemas to Elixir modules.
#
# Parses Bebop schema files and generates Elixir encoder/decoder modules that
# implement the Bebop wire format: 1-byte union discriminator tags, uint32-LE
# length-prefixed strings, float32-LE, uint8/16/32.
#
# Usage:
#   mix bebop.generate                    # Generate all schemas
#   mix bebop.generate voice_signal       # Generate one schema
#
# The generated modules live in lib/burble/protocol/ and contain encode/1 and
# decode/1 functions for each Bebop union type.

defmodule Mix.Tasks.Bebop.Generate do
  @moduledoc """
  Generate Elixir encoder/decoder modules from Bebop `.bop` schema files.

  Reads `.bop` files from `priv/schemas/`, parses enum, struct, message, and
  union definitions, then emits Elixir source code implementing the Bebop
  binary wire format.

  ## Wire format

  - **Strings**: `<<length::32-little, bytes::binary-size(length)>>`
  - **Bool**: `<<0 | 1 :: 8>>`
  - **uint8/uint16/uint32**: little-endian unsigned integers
  - **float32**: IEEE 754 little-endian
  - **Union**: `<<discriminator_tag::8, variant_payload::binary>>`

  ## Generated output

  Each `.bop` file produces a corresponding Elixir module in
  `lib/burble/protocol/` with `encode/1` and `decode/1` functions.
  """

  use Mix.Task

  @shortdoc "Generate Elixir protocol modules from Bebop .bop schemas"

  @schema_dir "priv/schemas"
  @output_dir "lib/burble/protocol"

  # ---------------------------------------------------------------------------
  # Entry point
  # ---------------------------------------------------------------------------

  @impl Mix.Task
  def run(args) do
    # Determine which schemas to process — all if no args, else filter.
    schema_files = list_schemas()

    targets =
      case args do
        [] ->
          schema_files

        names ->
          Enum.filter(schema_files, fn path ->
            base = Path.basename(path, ".bop")
            base in names
          end)
      end

    if targets == [] do
      Mix.shell().error("No .bop schemas found in #{@schema_dir}/")
      exit({:shutdown, 1})
    end

    File.mkdir_p!(@output_dir)

    Enum.each(targets, fn schema_path ->
      Mix.shell().info("Parsing #{schema_path}...")
      source = File.read!(schema_path)
      {ast, docs} = parse(source)
      module_name = module_name_from_path(schema_path)
      code = generate_module(module_name, schema_path, ast, docs)
      out_file = Path.join(@output_dir, snake_case(Path.basename(schema_path, ".bop")) <> ".ex")
      File.write!(out_file, code)
      Mix.shell().info("  -> #{out_file}")
    end)

    Mix.shell().info("Bebop codegen complete.")
  end

  # ---------------------------------------------------------------------------
  # Schema file discovery
  # ---------------------------------------------------------------------------

  # List all .bop files in the schemas directory.
  defp list_schemas do
    Path.wildcard(Path.join(@schema_dir, "*.bop"))
  end

  # Convert a file path like "priv/schemas/voice_signal.bop" to a module name
  # like "Burble.Protocol.VoiceSignal".
  defp module_name_from_path(path) do
    base = Path.basename(path, ".bop")
    camel = base |> String.split("_") |> Enum.map_join(&String.capitalize/1)
    "Burble.Protocol.#{camel}"
  end

  # ---------------------------------------------------------------------------
  # Parser — extracts enums, structs, messages, and unions from .bop source
  # ---------------------------------------------------------------------------

  # The parser produces a list of tagged tuples:
  #   {:enum, name, base_type, variants}
  #   {:struct, name, fields}
  #   {:message, name, fields}
  #   {:union, name, variants}

  defp parse(source) do
    # Doc comments (///) are collected BEFORE stripping, keyed by the
    # declaration they precede — they feed the emitted @moduledoc/@doc.
    docs = collect_docs(source)

    # Strip comments (// to end of line) but preserve string content.
    lines =
      source
      |> String.split("\n")
      |> Enum.map(&strip_comment/1)
      |> Enum.join("\n")

    {parse_top_level(lines, []), docs}
  end

  # Collect /// doc-comment blocks, keyed by the name of the enum/struct/
  # message/union declaration that immediately follows them. Any other
  # non-doc line (including a blank) resets the pending block, so stray
  # comments never attach to a distant declaration.
  defp collect_docs(source) do
    {map, _pending} =
      source
      |> String.split("\n")
      |> Enum.reduce({%{}, []}, fn raw, {map, pending} ->
        line = String.trim(raw)

        if String.starts_with?(line, "///") do
          text = line |> String.replace_prefix("///", "") |> String.trim()
          {map, pending ++ [text]}
        else
          case Regex.run(~r/^(?:enum|struct|message|union)\s+(\w+)/, line) do
            [_, name] -> {Map.put(map, name, pending), []}
            nil -> {map, []}
          end
        end
      end)

    map
  end

  # Normalise a declaration's doc first-line into the wire-table Direction
  # column ("Client -> Server" / "Server -> Client" / "Bidirectional").
  defp direction_of(type_name, docs) do
    case Map.get(docs, type_name) do
      [first | _] ->
        cond do
          String.starts_with?(first, "Client") and String.contains?(first, "Server") ->
            "Client -> Server"

          String.starts_with?(first, "Server") and String.contains?(first, "Client") ->
            "Server -> Client"

          String.starts_with?(first, "Bidirectional") ->
            "Bidirectional"

          true ->
            "-"
        end

      _ ->
        "-"
    end
  end

  # Strip a single-line comment, respecting that we don't have string literals
  # containing // in Bebop schemas (safe simplification).
  defp strip_comment(line) do
    case :binary.match(line, "//") do
      :nomatch -> line
      {pos, _} -> binary_part(line, 0, pos)
    end
  end

  # Top-level parser: scan for enum, struct, message, union keywords.
  defp parse_top_level("", acc), do: Enum.reverse(acc)

  defp parse_top_level(input, acc) do
    input = String.trim_leading(input)

    cond do
      input == "" ->
        Enum.reverse(acc)

      # enum Name : baseType { ... }
      String.starts_with?(input, "enum ") ->
        {item, rest} = parse_enum(input)
        parse_top_level(rest, [item | acc])

      # struct Name { ... }
      String.starts_with?(input, "struct ") ->
        {item, rest} = parse_struct(input)
        parse_top_level(rest, [item | acc])

      # message Name { ... }
      String.starts_with?(input, "message ") ->
        {item, rest} = parse_message(input)
        parse_top_level(rest, [item | acc])

      # union Name { ... }
      String.starts_with?(input, "union ") ->
        {item, rest} = parse_union(input)
        parse_top_level(rest, [item | acc])

      true ->
        # Skip unrecognised line (blank, comment residue, etc.)
        {_line, rest} = split_next_line(input)
        parse_top_level(rest, acc)
    end
  end

  # Parse: enum Name : baseType { Variant = N; ... }
  defp parse_enum(input) do
    # Match "enum <Name> : <type> {"
    regex = ~r/^enum\s+(\w+)\s*:\s*(\w+)\s*\{/
    [_, name, base_type] = Regex.run(regex, input)
    {body, rest} = extract_braced_body(input)

    variants =
      body
      |> String.split(";")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case Regex.run(~r/^(\w+)\s*=\s*(\d+)/, line) do
          [_, vname, vval] -> {vname, String.to_integer(vval)}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {{:enum, name, base_type, variants}, rest}
  end

  # Parse: struct Name { type field; ... }
  defp parse_struct(input) do
    [_, name] = Regex.run(~r/^struct\s+(\w+)\s*\{/, input)
    {body, rest} = extract_braced_body(input)

    fields =
      body
      |> String.split(";")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case Regex.run(~r/^(\w+)\s+(\w+)/, line) do
          [_, type, fname] -> {type, fname}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {{:struct, name, fields}, rest}
  end

  # Parse: message Name { N -> type field; ... }
  defp parse_message(input) do
    [_, name] = Regex.run(~r/^message\s+(\w+)\s*\{/, input)
    {body, rest} = extract_braced_body(input)

    fields =
      body
      |> String.split(";")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case Regex.run(~r/^(\d+)\s*->\s*(\w+)\s+(\w+)/, line) do
          [_, index, type, fname] -> {String.to_integer(index), type, fname}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {{:message, name, fields}, rest}
  end

  # Parse: union Name { N -> MessageType variantName; ... }
  defp parse_union(input) do
    [_, name] = Regex.run(~r/^union\s+(\w+)\s*\{/, input)
    {body, rest} = extract_braced_body(input)

    variants =
      body
      |> String.split(";")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        case Regex.run(~r/^(\d+)\s*->\s*(\w+)\s+(\w+)/, line) do
          [_, tag, type_name, var_name] ->
            {String.to_integer(tag), type_name, var_name}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {{:union, name, variants}, rest}
  end

  # Extract the body between the first { and its matching }, returning
  # {body_string, remaining_input_after_closing_brace}.
  defp extract_braced_body(input) do
    # Find the opening brace and extract everything after it.
    after_brace =
      case :binary.match(input, "{") do
        {pos, 1} ->
          binary_part(input, pos + 1, byte_size(input) - pos - 1)

        :nomatch ->
          input
      end

    # Count braces to find the matching close. `after_brace` is passed twice:
    # once as the cursor that gets consumed, once as the immutable original the
    # final slice is taken from.
    find_matching_close(after_brace, after_brace, 1, 0)
  end

  # `pos` counts bytes from the START of the body, so the slice must be taken
  # from the ORIGINAL body binary — not from `input`, which has already been
  # consumed down to the tail. Slicing the tail either crashes (when the tail
  # is shorter than `pos`) or silently returns the wrong text.
  defp find_matching_close(<<>>, _orig, _depth, _pos), do: {"", ""}

  defp find_matching_close(input, orig, depth, pos) do
    case input do
      <<"{", rest::binary>> ->
        find_matching_close(rest, orig, depth + 1, pos + 1)

      <<"}", rest::binary>> when depth == 1 ->
        {binary_part(orig, 0, pos), rest}

      # A nested close must DECREMENT the depth. Without this clause it fell
      # through to the catch-all as an ordinary character, so depth only ever
      # rose and a nested block could never close.
      <<"}", rest::binary>> ->
        find_matching_close(rest, orig, depth - 1, pos + 1)

      <<char::utf8, rest::binary>> ->
        find_matching_close(rest, orig, depth, pos + byte_size(<<char::utf8>>))
    end
  end

  # Split input at the first newline.
  defp split_next_line(input) do
    case String.split(input, "\n", parts: 2) do
      [line, rest] -> {line, rest}
      [line] -> {line, ""}
    end
  end

  # ---------------------------------------------------------------------------
  # Code generation
  # ---------------------------------------------------------------------------

  defp generate_module(module_name, schema_path, ast, docs) do
    # Separate AST nodes by type for organised code generation.
    enums = for {:enum, n, bt, vs} <- ast, do: {:enum, n, bt, vs}
    structs = for {:struct, n, fs} <- ast, do: {:struct, n, fs}
    messages = for {:message, n, fs} <- ast, do: {:message, n, fs}
    unions = for {:union, n, vs} <- ast, do: {:union, n, vs}

    # Build a lookup from type name -> AST node for resolving references.
    type_map = build_type_map(ast)

    header = """
    # SPDX-License-Identifier: MPL-2.0
    # Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
    #
    # Generated from: #{schema_path}
    # Generator: mix bebop.generate
    # DO NOT EDIT — regenerate with `mix bebop.generate`
    #
    # Bebop wire format: little-endian, length-prefixed strings (uint32 + UTF-8),
    # 1-byte union discriminator tag.

    defmodule #{module_name} do
      @moduledoc \"\"\"
      Bebop encoder/decoder for #{Path.basename(schema_path, ".bop")}.

      Auto-generated from `#{schema_path}`. Provides `encode/1` and `decode/1`
      for the top-level union type(s), plus struct/message codec helpers.

      ## Wire format

      - **Strings**: uint32-LE length prefix followed by UTF-8 bytes
      - **Bool**: one byte, `0` or `1` — any other byte is malformed
      - **uint8/uint16/uint32**: little-endian; **float32**: IEEE 754 LE
      - **Union**: 1-byte discriminator tag, then the variant payload

      Decoders are STRICT: truncated or malformed input raises
      `Burble.BebopDecodeError`. A frame that declares more bytes than it
      carries is rejected — never silently decoded to empty values.
    #{gen_union_tables(unions, docs)}  \"\"\"
    """

    enum_code = Enum.map(enums, &gen_enum(&1, docs)) |> Enum.join("\n")
    struct_code = Enum.map(structs, &gen_struct_codec(&1, type_map, docs)) |> Enum.join("\n")
    message_code = Enum.map(messages, &gen_message_codec(&1, type_map, docs)) |> Enum.join("\n")
    union_code = Enum.map(unions, &gen_union_codec(&1, type_map, docs)) |> Enum.join("\n")

    primitives = gen_primitives()

    footer = "\nend\n"

    header <> enum_code <> "\n" <> struct_code <> "\n" <> message_code <> "\n" <>
      union_code <> "\n" <> primitives <> footer
  end

  # Render one "## <Union> tags" moduledoc table per union, with the Direction
  # column derived from each variant type's /// doc first line in the schema.
  # Built by concatenation (not heredoc) so the two-space moduledoc indent is
  # explicit and the output stays byte-deterministic.
  defp gen_union_tables([], _docs), do: ""

  defp gen_union_tables(unions, docs) do
    Enum.map_join(unions, "", fn {:union, name, variants} ->
      sorted = Enum.sort_by(variants, fn {tag, _, _} -> tag end)

      type_w =
        sorted |> Enum.map(fn {_, t, _} -> String.length(t) end) |> Enum.max() |> max(7)

      dir_w =
        sorted
        |> Enum.map(fn {_, t, _} -> String.length(direction_of(t, docs)) end)
        |> Enum.max()
        |> max(9)

      head =
        "\n  ## #{name} tags\n\n" <>
          "  Each #{name} message is prefixed with a 1-byte discriminator tag:\n\n" <>
          "  | Tag | #{String.pad_trailing("Variant", type_w)} | #{String.pad_trailing("Direction", dir_w)} |\n" <>
          "  |-----|#{String.duplicate("-", type_w + 2)}|#{String.duplicate("-", dir_w + 2)}|\n"

      rows =
        Enum.map_join(sorted, "", fn {tag, type_name, _var} ->
          "  | #{String.pad_leading(to_string(tag), 3)} | #{String.pad_trailing(type_name, type_w)} | #{String.pad_trailing(direction_of(type_name, docs), dir_w)} |\n"
        end)

      head <> rows
    end)
  end

  # Build a map of type_name -> AST node for cross-referencing.
  defp build_type_map(ast) do
    Enum.reduce(ast, %{}, fn
      {:enum, name, _, _} = node, acc -> Map.put(acc, name, node)
      {:struct, name, _} = node, acc -> Map.put(acc, name, node)
      {:message, name, _} = node, acc -> Map.put(acc, name, node)
      {:union, name, _} = node, acc -> Map.put(acc, name, node)
    end)
  end

  # Generate enum encode/decode functions: atom->int clauses, then int->atom,
  # then a guarded catch-all so an unknown wire value is a structured decode
  # error instead of a bare FunctionClauseError.
  defp gen_enum({:enum, name, _base_type, variants}, docs) do
    func_name = snake_case(name)

    summary =
      Enum.map_join(variants, ", ", fn {vname, val} -> "#{vname} (#{val})" end)

    to_int =
      Enum.map_join(variants, "", fn {vname, val} ->
        "  def #{func_name}(:#{snake_case(vname)}), do: #{val}\n"
      end)

    to_atom =
      Enum.map_join(variants, "", fn {vname, val} ->
        "  def #{func_name}(#{val}), do: :#{snake_case(vname)}\n"
      end)

    catch_all =
      "\n  def #{func_name}(other) when is_integer(other) do\n" <>
        "    raise Burble.BebopDecodeError, \"unknown #{name} value \#{other}\"\n" <>
        "  end\n"

    banner("Enum: #{name}", docs, name) <>
      "  @doc \"#{name} enum — #{summary}.\"\n" <>
      to_int <> to_atom <> catch_all
  end

  # Section banner in the committed style, carrying the schema's /// doc
  # first line when one exists.
  defp banner(title, docs, type_name) do
    doc_line =
      case Map.get(docs, type_name) do
        [first | _] -> "  # #{first}\n"
        _ -> ""
      end

    "\n  # " <> String.duplicate("-", 75) <> "\n" <>
      "  # #{title}\n" <>
      doc_line <>
      "  # " <> String.duplicate("-", 75) <> "\n\n"
  end

  # Generate struct encode/decode.
  defp gen_struct_codec({:struct, name, fields}, type_map, docs) do
    enc_name = "encode_#{snake_case(name)}"
    dec_name = "decode_#{snake_case(name)}"

    # Build the map pattern for encode.
    map_keys = Enum.map(fields, fn {_type, fname} -> "#{snake_case(fname)}: #{snake_case(fname)}" end) |> Enum.join(", ")

    # Build encode body — concatenation of field encoders.
    enc_parts = Enum.map(fields, fn {type, fname} ->
      encode_field_expr(type, snake_case(fname), type_map)
    end) |> Enum.join(" <>\n      ")

    # Build decode body — sequential decoding.
    {dec_bindings, _counter} = Enum.reduce(fields, {[], 0}, fn {type, fname}, {acc, i} ->
      var = snake_case(fname)
      rest_var = if i == 0, do: "data", else: "rest#{i}"
      next_rest = "rest#{i + 1}"
      binding = decode_field_expr(type, var, rest_var, next_rest, type_map)
      {acc ++ [binding], i + 1}
    end)

    last_rest = "rest#{length(fields)}"
    result_map = Enum.map(fields, fn {_type, fname} ->
      sn = snake_case(fname)
      "#{sn}: #{sn}"
    end) |> Enum.join(", ")

    banner("Struct: #{name}", docs, name) <>
      """
        @doc "Encode a #{name} struct to Bebop binary."
        def #{enc_name}(%{#{map_keys}}) do
          #{enc_parts}
        end

        @doc "Decode a #{name} struct from Bebop binary. Returns {struct_map, rest}."
        def #{dec_name}(data) do
      #{Enum.join(dec_bindings, "\n")}
          {%{#{result_map}}, #{last_rest}}
        end
      """
  end

  # Generate message encode/decode (messages have indexed fields like structs
  # but we treat them identically for wire format since Bebop messages encode
  # fields in index order with no field tags on the wire).
  defp gen_message_codec({:message, name, fields}, type_map, docs) do
    enc_name = "encode_#{snake_case(name)}"
    dec_name = "decode_#{snake_case(name)}"

    sorted_fields = Enum.sort_by(fields, fn {idx, _, _} -> idx end)

    map_keys = Enum.map(sorted_fields, fn {_idx, _type, fname} ->
      "#{snake_case(fname)}: #{snake_case(fname)}"
    end) |> Enum.join(", ")

    enc_parts = Enum.map(sorted_fields, fn {_idx, type, fname} ->
      encode_field_expr(type, snake_case(fname), type_map)
    end) |> Enum.join(" <>\n      ")

    {dec_bindings, _counter} = Enum.reduce(sorted_fields, {[], 0}, fn {_idx, type, fname}, {acc, i} ->
      var = snake_case(fname)
      rest_var = if i == 0, do: "data", else: "rest#{i}"
      next_rest = "rest#{i + 1}"
      binding = decode_field_expr(type, var, rest_var, next_rest, type_map)
      {acc ++ [binding], i + 1}
    end)

    last_rest = "rest#{length(sorted_fields)}"
    result_map = Enum.map(sorted_fields, fn {_idx, _type, fname} ->
      sn = snake_case(fname)
      "#{sn}: #{sn}"
    end) |> Enum.join(", ")

    banner("Message: #{name}", docs, name) <>
      """
        @doc "Encode a #{name} message to Bebop binary (no discriminator tag)."
        def #{enc_name}(%{#{map_keys}}) do
          #{enc_parts}
        end

        @doc "Decode a #{name} message from Bebop binary. Returns {msg_map, rest}."
        def #{dec_name}(data) do
      #{Enum.join(dec_bindings, "\n")}
          {%{#{result_map}}, #{last_rest}}
        end
      """
  end

  # Generate union encode/decode — this is the top-level entry point.
  defp gen_union_codec({:union, name, variants}, type_map, docs) do
    enc_clauses = Enum.map(variants, fn {tag, type_name, var_name} ->
      atom_name = snake_case(var_name)
      enc_fn = "encode_#{snake_case(type_name)}"
      """
        def encode({:#{atom_name}, msg}) do
          payload = #{enc_fn}(msg)
          <<#{tag}::8, payload::binary>>
        end
      """
    end) |> Enum.join("\n")

    dec_clauses = Enum.map(variants, fn {tag, type_name, var_name} ->
      atom_name = snake_case(var_name)
      dec_fn = "decode_#{snake_case(type_name)}"
      """
        def decode(<<#{tag}::8, payload::binary>>) do
          {msg, rest} = #{dec_fn}(payload)
          {:#{atom_name}, msg, rest}
        end
      """
    end) |> Enum.join("\n")

    banner("Union: #{name} — top-level encode/decode on the discriminator tag", docs, name) <>
      """
      #{enc_clauses}
        def encode({unknown_tag, _msg}) do
          raise ArgumentError, "Unknown #{name} variant: \#{inspect(unknown_tag)}"
        end

      #{dec_clauses}
        def decode(<<tag::8, _::binary>>) do
          {:error, "Unknown #{name} discriminator tag: \#{tag}"}
        end

        def decode(<<>>) do
          {:error, "Empty input — no discriminator tag"}
        end
      """
  end

  # ---------------------------------------------------------------------------
  # Field-level encode/decode expression generators
  # ---------------------------------------------------------------------------

  # Generate an Elixir expression that encodes a single field value to binary.
  defp encode_field_expr(type, var, type_map) do
    case type do
      "string" -> "encode_string(#{var})"
      "float32" -> "<<#{var}::float-little-32>>"
      "uint8" -> "<<#{var}::8>>"
      "uint16" -> "<<#{var}::16-little>>"
      "uint32" -> "<<#{var}::32-little>>"
      "bool" -> "encode_bool(#{var})"
      other ->
        # Check if this is a known struct/message/enum type.
        cond do
          Map.has_key?(type_map, other) ->
            case Map.get(type_map, other) do
              {:enum, _, _, _} -> "<<#{snake_case(other)}(#{var})::8>>"
              {:struct, _, _} -> "encode_#{snake_case(other)}(#{var})"
              {:message, _, _} -> "encode_#{snake_case(other)}(#{var})"
              _ -> "encode_#{snake_case(other)}(#{var})"
            end

          true ->
            "encode_#{snake_case(other)}(#{var})"
        end
    end
  end

  # Generate an Elixir binding expression that decodes a single field from binary.
  # Returns a string like "    {var, rest2} = decode_string(rest1)".
  #
  # Every fixed-width field goes through a decode_* helper rather than a bare
  # binary pattern match: a bare match on truncated input raises MatchError
  # with no context, while the helpers raise Burble.BebopDecodeError with the
  # field width and the bytes actually available.
  defp decode_field_expr(type, var, rest_in, rest_out, type_map) do
    case type do
      "string" ->
        "    {#{var}, #{rest_out}} = decode_string(#{rest_in})"

      "float32" ->
        "    {#{var}, #{rest_out}} = decode_float32(#{rest_in})"

      "uint8" ->
        "    {#{var}, #{rest_out}} = decode_uint8(#{rest_in})"

      "uint16" ->
        "    {#{var}, #{rest_out}} = decode_uint16(#{rest_in})"

      "uint32" ->
        "    {#{var}, #{rest_out}} = decode_uint32(#{rest_in})"

      "bool" ->
        "    {#{var}, #{rest_out}} = decode_bool(#{rest_in})"

      other ->
        cond do
          Map.has_key?(type_map, other) ->
            case Map.get(type_map, other) do
              {:enum, _, _, _} ->
                "    {#{var}_raw, #{rest_out}} = decode_uint8(#{rest_in})\n" <>
                  "    #{var} = #{snake_case(other)}(#{var}_raw)"

              {:struct, _, _} ->
                "    {#{var}, #{rest_out}} = decode_#{snake_case(other)}(#{rest_in})"

              {:message, _, _} ->
                "    {#{var}, #{rest_out}} = decode_#{snake_case(other)}(#{rest_in})"

              _ ->
                "    {#{var}, #{rest_out}} = decode_#{snake_case(other)}(#{rest_in})"
            end

          true ->
            "    {#{var}, #{rest_out}} = decode_#{snake_case(other)}(#{rest_in})"
        end
    end
  end

  # Generate the shared primitive encode/decode functions.
  #
  # STRICT decoders (A4): every length prefix is bounds-checked against the
  # bytes actually present, and malformed input raises Burble.BebopDecodeError.
  # The old lenient behaviour — a truncated string decoding to "" without
  # consuming anything, a garbage bool byte decoding to false — let a
  # truncated frame arrive as a valid-looking EMPTY message.
  defp gen_primitives do
    """

      # ---------------------------------------------------------------------------
      # Primitive codecs (Bebop wire format) — strict: malformed input raises
      # Burble.BebopDecodeError instead of decoding to a default value.
      # ---------------------------------------------------------------------------

      @doc "Encode a Bebop string: uint32-LE length prefix followed by UTF-8 bytes."
      def encode_string(str) when is_binary(str) do
        len = byte_size(str)
        <<len::32-little, str::binary>>
      end

      @doc "Decode a Bebop string. Returns {string, rest}; raises on truncation."
      def decode_string(<<len::32-little, str::binary-size(len), rest::binary>>) do
        {str, rest}
      end

      def decode_string(<<len::32-little, rest::binary>>) do
        raise Burble.BebopDecodeError,
              "string length \#{len} exceeds the \#{byte_size(rest)} bytes remaining"
      end

      def decode_string(data) do
        raise Burble.BebopDecodeError,
              "truncated string length prefix: \#{byte_size(data)} of 4 bytes"
      end

      @doc "Encode a boolean as a single byte (0 or 1)."
      def encode_bool(true), do: <<1::8>>
      def encode_bool(false), do: <<0::8>>

      @doc "Decode a boolean byte. Only 0 and 1 are valid; anything else raises."
      def decode_bool(<<1::8, rest::binary>>), do: {true, rest}
      def decode_bool(<<0::8, rest::binary>>), do: {false, rest}

      def decode_bool(<<other::8, _::binary>>) do
        raise Burble.BebopDecodeError, "invalid bool byte \#{other} (want 0 or 1)"
      end

      def decode_bool(<<>>) do
        raise Burble.BebopDecodeError, "truncated bool: 0 of 1 bytes"
      end

      @doc "Decode a uint8. Returns {value, rest}; raises on truncation."
      def decode_uint8(<<v::8, rest::binary>>), do: {v, rest}

      def decode_uint8(data) do
        raise Burble.BebopDecodeError,
              "truncated uint8: \#{byte_size(data)} of 1 bytes"
      end

      @doc "Decode a uint16 (little-endian). Returns {value, rest}; raises on truncation."
      def decode_uint16(<<v::16-little, rest::binary>>), do: {v, rest}

      def decode_uint16(data) do
        raise Burble.BebopDecodeError,
              "truncated uint16: \#{byte_size(data)} of 2 bytes"
      end

      @doc "Decode a uint32 (little-endian). Returns {value, rest}; raises on truncation."
      def decode_uint32(<<v::32-little, rest::binary>>), do: {v, rest}

      def decode_uint32(data) do
        raise Burble.BebopDecodeError,
              "truncated uint32: \#{byte_size(data)} of 4 bytes"
      end

      @doc "Decode a float32 (IEEE 754 LE). Returns {value, rest}; raises on truncation. NaN/Inf bit patterns do not match Elixir float segments and are rejected too."
      def decode_float32(<<v::float-little-32, rest::binary>>), do: {v, rest}

      def decode_float32(data) do
        raise Burble.BebopDecodeError,
              "truncated or non-finite float32 (\#{byte_size(data)} bytes available)"
      end
    """
  end

  # ---------------------------------------------------------------------------
  # Naming helpers
  # ---------------------------------------------------------------------------

  # Convert a CamelCase or PascalCase name to snake_case.
  defp snake_case(name) do
    name
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end
end
