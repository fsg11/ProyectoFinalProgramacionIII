defmodule Emergencias.Mensajes do
  @moduledoc """
  GenServer para los mensajes entre familiares.

  Estado: %{mensajes: %{"MSG001" => %Mensaje{}, ...}, contador: 1}
  """

  use GenServer
  alias Emergencias.{Mensaje, Persistencia, Util}

  @archivo "mensajes.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def enviar(remitente, destinatario, contenido),
    do: GenServer.call(__MODULE__, {:enviar, remitente, destinatario, contenido})

  def listar(destinatario), do: GenServer.call(__MODULE__, {:listar, destinatario})

  def marcar(id, estado), do: GenServer.call(__MODULE__, {:marcar, id, estado})

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    mensajes =
      @archivo
      |> Persistencia.leer(&Mensaje.desde_campos/1)
      |> Map.new(fn m -> {m.id, m} end)

    {:ok, %{mensajes: mensajes, contador: map_size(mensajes)}}
  end

  @impl true
  def handle_call({:enviar, remitente, destinatario, contenido}, _from, estado) do
    contador = estado.contador + 1
    id = Util.generar_id("MSG", contador)

    case Mensaje.crear(id, remitente, destinatario, contenido) do
      {:ok, mensaje} ->
        nuevo_estado = %{mensajes: Map.put(estado.mensajes, id, mensaje), contador: contador}
        guardar(nuevo_estado)
        {:reply, {:ok, mensaje}, nuevo_estado}

      {:error, error} ->
        {:reply, {:error, error}, estado}
    end
  end

  def handle_call({:listar, destinatario}, _from, estado) do
    lista =
      estado.mensajes
      |> Map.values()
      |> Enum.filter(fn m -> m.destinatario == destinatario end)
      |> Enum.sort_by(fn m -> {m.fecha, m.id} end)

    {:reply, lista, estado}
  end

  def handle_call({:marcar, id, nuevo}, _from, estado) do
    id = String.upcase(id)

    with {:ok, mensaje} <- buscar(estado, id),
         {:ok, actualizado} <- Mensaje.marcar(mensaje, nuevo) do
      nuevo_estado = %{estado | mensajes: Map.put(estado.mensajes, id, actualizado)}
      guardar(nuevo_estado)
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      {:error, error} -> {:reply, {:error, error}, estado}
    end
  end

  def handle_call(:resumen, _from, estado) do
    mensajes = Map.values(estado.mensajes)

    resumen = %{
      total: length(mensajes),
      por_estado: Enum.frequencies_by(mensajes, fn m -> m.estado end)
    }

    {:reply, resumen, estado}
  end

  defp buscar(estado, id) do
    case Map.fetch(estado.mensajes, id) do
      {:ok, mensaje} -> {:ok, mensaje}
      :error -> {:error, "No existe el mensaje #{id}"}
    end
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.mensajes), &Mensaje.a_campos/1)
  end
end
