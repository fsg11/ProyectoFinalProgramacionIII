defmodule Emergencias.Personas do
  @moduledoc """
  GenServer que administra las personas afectadas y el historial de sus
  cambios de estado.

  Estado:

      %{
        personas: %{"1094" => %Persona{}, ...},
        historial: [%{fecha, documento, anterior, nuevo, usuario}, ...]  # más reciente primero
      }
  """

  use GenServer
  alias Emergencias.{Persistencia, Persona, Util}

  @archivo "personas.txt"
  @archivo_historial "historial_personas.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(persona, usuario), do: GenServer.call(__MODULE__, {:registrar, persona, usuario})

  def obtener(documento), do: GenServer.call(__MODULE__, {:obtener, documento})

  def cambiar_estado(documento, estado, usuario),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, estado, usuario})

  @doc "Busca con filtros [{campo, valor}]. El nombre se busca de forma parcial."
  def buscar(filtros), do: GenServer.call(__MODULE__, {:buscar, filtros})

  def historial(documento), do: GenServer.call(__MODULE__, {:historial, documento})

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    personas =
      @archivo
      |> Persistencia.leer(&Persona.desde_campos/1)
      |> Map.new(fn p -> {p.documento, p} end)

    historial =
      @archivo_historial
      |> Persistencia.leer(&historial_desde_campos/1)
      |> Enum.reverse()

    {:ok, %{personas: personas, historial: historial}}
  end

  @impl true
  def handle_call({:registrar, persona, usuario}, _from, estado) do
    if Map.has_key?(estado.personas, persona.documento) do
      {:reply, {:error, "Ya existe una persona con el documento #{persona.documento}"}, estado}
    else
      nuevo_estado =
        estado
        |> actualizar(persona)
        |> registrar_historial(persona.documento, "-", persona.estado, usuario)

      guardar(nuevo_estado)
      {:reply, {:ok, persona}, nuevo_estado}
    end
  end

  def handle_call({:obtener, documento}, _from, estado) do
    {:reply, buscar_persona(estado, documento), estado}
  end

  def handle_call({:cambiar_estado, documento, nuevo, usuario}, _from, estado) do
    with {:ok, persona} <- buscar_persona(estado, documento),
         {:ok, actualizada} <- Persona.cambiar_estado(persona, nuevo) do
      nuevo_estado =
        estado
        |> actualizar(actualizada)
        |> registrar_historial(documento, persona.estado, nuevo, usuario)

      guardar(nuevo_estado)
      {:reply, {:ok, actualizada}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:buscar, filtros}, _from, estado) do
    lista =
      estado.personas
      |> Map.values()
      |> Enum.filter(fn persona -> Enum.all?(filtros, &cumple?(persona, &1)) end)
      |> Enum.sort_by(fn persona -> persona.nombre end)

    {:reply, lista, estado}
  end

  def handle_call({:historial, documento}, _from, estado) do
    lista =
      estado.historial
      |> Enum.filter(fn registro -> registro.documento == documento end)
      |> Enum.reverse()

    {:reply, lista, estado}
  end

  def handle_call(:resumen, _from, estado) do
    personas = Map.values(estado.personas)

    resumen = %{
      total: length(personas),
      por_estado: Enum.frequencies_by(personas, fn p -> p.estado end)
    }

    {:reply, resumen, estado}
  end

  # El nombre se compara de forma parcial ("andr" encuentra a "Andrés").
  defp cumple?(persona, {"nombre", valor}),
    do: String.contains?(Util.normalizar(persona.nombre), valor)

  defp cumple?(persona, filtro), do: Util.cumple_filtros?(persona, [filtro])

  defp buscar_persona(estado, documento) do
    case Map.fetch(estado.personas, documento) do
      {:ok, persona} -> {:ok, persona}
      :error -> {:error, "No existe una persona con el documento #{documento}"}
    end
  end

  defp actualizar(estado, persona) do
    %{estado | personas: Map.put(estado.personas, persona.documento, persona)}
  end

  defp registrar_historial(estado, documento, anterior, nuevo, usuario) do
    registro = %{
      fecha: Util.fecha_actual(),
      documento: documento,
      anterior: anterior,
      nuevo: nuevo,
      usuario: usuario
    }

    Persistencia.agregar(@archivo_historial, [registro.fecha, documento, anterior, nuevo, usuario])
    %{estado | historial: [registro | estado.historial]}
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.personas), &Persona.a_campos/1)
  end

  defp historial_desde_campos([fecha, documento, anterior, nuevo, usuario]) do
    %{fecha: fecha, documento: documento, anterior: anterior, nuevo: nuevo, usuario: usuario}
  end

  defp historial_desde_campos(_campos), do: nil
end
