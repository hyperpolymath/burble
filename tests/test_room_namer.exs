#!/usr/bin/env elixir

# Test script for Burble.RoomNamer
Code.require_file("server/lib/burble/room_namer.ex", __DIR__)

IO.puts("=== Burble Room Namer Tests ===")

# Test 1: Generate multiple room names
IO.puts("\nTest 1: Generating 5 room names")
Enum.each(1..5, fn _ -> IO.inspect(Burble.RoomNamer.generate_room_name()) end)

# Test 2: Validate format
IO.puts("\nTest 2: Validating format")
room_name = Burble.RoomNamer.generate_room_name()
IO.puts("Generated: #{room_name}")
IO.puts("Valid format: #{Burble.RoomNamer.valid_room_name?(room_name)}")

# Test 3: Test invalid names
IO.puts("\nTest 3: Testing invalid names")
IO.puts("apple (invalid): #{Burble.RoomNamer.valid_room_name?("apple")}")
IO.puts("Apple-banana-cat (invalid): #{Burble.RoomNamer.valid_room_name?("Apple-banana-cat")}")
IO.puts("apple-banana-cat-dog (invalid): #{Burble.RoomNamer.valid_room_name?("apple-banana-cat-dog")}")

# Test 4: Check word list coverage
IO.puts("\nTest 4: Checking word variety")
names = Enum.map(1..20, fn _ -> Burble.RoomNamer.generate_room_name() end)
unique_words = names |> Enum.flat_map(&String.split(&1, "-")) |> Enum.uniq()
IO.puts("Generated #{length(names)} names with #{length(unique_words)} unique words")

IO.puts("\n=== All tests completed ===")