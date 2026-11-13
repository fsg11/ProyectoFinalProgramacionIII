defmodule EmergenciasWeb.ErrorHTML do
  @moduledoc "Páginas de error (404, 500...) como texto simple."

  def render(plantilla, _assigns) do
    Phoenix.Controller.status_message_from_template(plantilla)
  end
end
