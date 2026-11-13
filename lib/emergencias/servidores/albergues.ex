defmodule Emergencias.Albergues do
  @moduledoc """
  GenServer que administra los albergues y su ocupación.

  Estado: mapa codigo -> %Albergue{}.

  Si dos voluntarios registran al mismo tiempo el ingreso de personas al
  último cupo, el GenServer procesa una solicitud a la vez: la primera
  ocupa el cupo y la segunda recibe "albergue lleno".
  """

  use GenServer
  alias Emergencias.{Albergue, Persistencia}

  @archivo "albergues.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(albergue), do: GenServer.call(__MODULE__, {:registrar, albergue})

  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  def ingresar(codigo, documento), do: GenServer.call(__MODULE__, {:ingresar, codigo, documento})

  def salir(codigo, documento), do: GenServer.call(__MODULE__, {:salir, codigo, documento})

  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc "Albergues ordenados de mayor a menor porcentaje de ocupación."
  def reporte_ocupacion, do: GenServer.call(__MODULE__, :reporte_ocupacion)

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    albergues =
      @archivo
      |> Persistencia.leer(&Albergue.desde_campos/1)
      |> Map.new(fn a -> {a.codigo, a} end)

    {:ok, albergues}
  end

  @impl true
  def handle_call({:registrar, albergue}, _from, albergues) do
    if Map.has_key?(albergues, albergue.codigo) do
      {:reply, {:error, "Ya existe un albergue con el código #{albergue.codigo}"}, albergues}
    else
      nuevos = Map.put(albergues, albergue.codigo, albergue)
      guardar(nuevos)
      {:reply, {:ok, albergue}, nuevos}
    end
  end

  def handle_call({:obtener, codigo}, _from, albergues) do
    {:reply, buscar(albergues, codigo), albergues}
  end

  def handle_call({:ingresar, codigo, documento}, _from, albergues) do
    with {:ok, albergue} <- buscar(albergues, codigo),
         :ok <- validar_no_alojada_en_otro(albergues, codigo, documento),
         {:ok, actualizado} <- Albergue.ingresar(albergue, documento) do
      nuevos = Map.put(albergues, codigo, actualizado)
      guardar(nuevos)
      {:reply, {:ok, actualizado}, nuevos}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, albergues}
    end
  end

  def handle_call({:salir, codigo, documento}, _from, albergues) do
    with {:ok, albergue} <- buscar(albergues, codigo),
         {:ok, actualizado} <- Albergue.salir(albergue, documento) do
      nuevos = Map.put(albergues, codigo, actualizado)
      guardar(nuevos)
      {:reply, {:ok, actualizado}, nuevos}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, albergues}
    end
  end

  def handle_call(:listar, _from, albergues) do
    {:reply, albergues |> Map.values() |> Enum.sort_by(fn a -> a.codigo end), albergues}
  end

  def handle_call(:reporte_ocupacion, _from, albergues) do
    lista =
      albergues
      |> Map.values()
      |> Enum.sort_by(fn a -> Albergue.porcentaje(a) end, :desc)

    {:reply, lista, albergues}
  end

  def handle_call(:resumen, _from, albergues) do
    lista = Map.values(albergues)

    resumen = %{
      total: length(lista),
      capacidad: Enum.sum(Enum.map(lista, fn a -> a.capacidad end)),
      ocupacion: Enum.sum(Enum.map(lista, &Albergue.ocupacion/1))
    }

    {:reply, resumen, albergues}
  end

  # Una persona solo puede estar en un albergue a la vez.
  defp validar_no_alojada_en_otro(albergues, codigo, documento) do
    otro =
      albergues
      |> Map.values()
      |> Enum.find(fn a -> a.codigo != codigo and MapSet.member?(a.ocupantes, documento) end)

    case otro do
      nil ->
        :ok

      albergue ->
        {:error,
         "La persona #{documento} ya está alojada en el albergue #{albergue.codigo}; " <>
           "registre primero su salida con register_exit"}
    end
  end

  defp buscar(albergues, codigo) do
    case Map.fetch(albergues, codigo) do
      {:ok, albergue} -> {:ok, albergue}
      :error -> {:error, "No existe el albergue #{codigo}"}
    end
  end

  defp guardar(albergues) do
    Persistencia.guardar(@archivo, Map.values(albergues), &Albergue.a_campos/1)
  end
end
