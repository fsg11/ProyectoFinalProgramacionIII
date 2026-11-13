defmodule Emergencias.Bitacora do
  @moduledoc """
  Registro de la actividad de los usuarios.

  Se implementa como un PROCESO SIMPLE (spawn + receive), igual que los
  ejemplos de procesos vistos en clase, para mostrar el paso de mensajes
  sin GenServer. El proceso queda registrado con el nombre `:bitacora`
  y es supervisado por el supervisor principal.

  Mensajes que entiende:

    * `{:registrar, usuario, accion}`  -> agrega una línea a bitacora.txt
    * `{:consultar, pid, usuario}`     -> responde `{:actividad, registros}`
  """

  alias Emergencias.{Persistencia, Util}

  @nombre :bitacora
  @archivo "bitacora.txt"

  def child_spec(_argumentos) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
  end

  def start_link do
    pid = spawn_link(__MODULE__, :atender_mensajes, [])
    Process.register(pid, @nombre)
    {:ok, pid}
  end

  @doc "Envía (sin esperar respuesta) un registro de actividad."
  def registrar(usuario, accion) do
    case Process.whereis(@nombre) do
      nil ->
        :error

      pid ->
        send(pid, {:registrar, usuario, accion})
        :ok
    end
  end

  @doc "Consulta la actividad de un usuario (o de todos si es nil)."
  def consultar(usuario \\ nil) do
    send(@nombre, {:consultar, self(), usuario})

    receive do
      {:actividad, registros} -> registros
    after
      5_000 -> []
    end
  end

  def atender_mensajes do
    receive do
      {:registrar, usuario, accion} ->
        Persistencia.agregar(@archivo, [Util.fecha_actual(), usuario, accion])
        atender_mensajes()

      {:consultar, cliente, usuario} ->
        registros =
          @archivo
          |> Persistencia.leer(&convertir/1)
          |> Enum.filter(fn registro -> usuario == nil or registro.usuario == usuario end)

        send(cliente, {:actividad, registros})
        atender_mensajes()

      _otro ->
        atender_mensajes()
    end
  end

  defp convertir([fecha, usuario, accion]), do: %{fecha: fecha, usuario: usuario, accion: accion}
  defp convertir(_campos), do: nil
end
