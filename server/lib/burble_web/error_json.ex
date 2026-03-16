# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule BurbleWeb.ErrorJSON do
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
