defmodule EmergenciasWeb.Autenticacion do
  @moduledoc "Valida la sesión de las páginas web y las mantiene actualizadas."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias Emergencias.{Notificador, Usuarios}

  def on_mount(:default, _parametros, sesion, socket) do
    with %{"usuario" => usuario, "token" => token} <- sesion,
         {:ok, datos} <- Usuarios.validar_sesion(usuario, token) do
      if connected?(socket), do: Phoenix.PubSub.subscribe(Emergencias.PubSub, Notificador.tema())

      socket =
        socket
        |> assign(:usuario, datos)
        |> assign(:sesion, %{usuario: usuario, token: token})
        |> assign(:resultado, nil)
        |> assign(:version, 0)
        |> attach_hook(:revalidar_sesion, :handle_info, &revalidar/2)
        |> attach_hook(:cerrar_resultado, :handle_event, &cerrar_resultado/3)

      {:cont, socket}
    else
      _ ->
        {:halt,
         socket
         |> put_flash(:error, "Inicie sesión para continuar.")
         |> redirect(to: "/")}
    end
  end

  defp revalidar(:datos_actualizados, socket) do
    %{usuario: usuario, token: token} = socket.assigns.sesion

    case Usuarios.validar_sesion(usuario, token) do
      {:ok, datos} ->
        {:cont, assign(socket, :usuario, datos)}

      {:error, mensaje} ->
        {:halt, socket |> put_flash(:error, mensaje) |> redirect(to: "/")}
    end
  end

  defp revalidar(_mensaje, socket), do: {:cont, socket}

  defp cerrar_resultado("cerrar_resultado", _parametros, socket),
    do: {:halt, assign(socket, :resultado, nil)}

  defp cerrar_resultado(_evento, _parametros, socket), do: {:cont, socket}
end
