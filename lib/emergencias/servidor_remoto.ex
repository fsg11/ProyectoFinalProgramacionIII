defmodule Emergencias.ServidorRemoto do
  @moduledoc """
  Recibe comandos de clientes que están en OTROS NODOS (otras terminales o
  computadores), igual que el ejemplo 30D-nodo-servidor del curso.

  Cada solicitud se atiende en un PROCESO NUEVO (spawn), así varios usuarios
  pueden trabajar al mismo tiempo sin esperar a que termine el anterior.
  La consistencia de los datos la garantizan los GenServers.

  Mensaje que entiende:

      {pid_cliente, {:comando, linea, sesion}}

  Respuesta que envía:

      {:respuesta, texto, nueva_sesion}
  """

  alias Emergencias.Comandos

  @nombre_servicio :servicio_emergencias

  def nombre_servicio, do: @nombre_servicio

  def child_spec(_argumentos) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
  end

  def start_link do
    pid = spawn_link(__MODULE__, :esperar_solicitudes, [])
    Process.register(pid, @nombre_servicio)
    {:ok, pid}
  end

  def esperar_solicitudes do
    receive do
      {cliente, {:comando, linea, sesion}} ->
        spawn(fn -> atender(cliente, linea, sesion) end)
        esperar_solicitudes()

      _otro ->
        esperar_solicitudes()
    end
  end

  defp atender(cliente, linea, sesion) do
    {texto, nueva_sesion} =
      try do
        Comandos.ejecutar(linea, sesion)
      rescue
        error -> {"Error inesperado en el servidor: #{Exception.message(error)}", sesion}
      catch
        :exit, _razon -> {"Error: el servidor no pudo completar la operación", sesion}
      end

    send(cliente, {:respuesta, texto, nueva_sesion})
  end
end
