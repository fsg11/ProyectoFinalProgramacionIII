defmodule Emergencias.Zonas do
  @moduledoc """
  GenServer que administra zonas, sectores y puntos de atención.

  Estado: mapa codigo -> %Zona{} (lista plana; cada zona conoce a su padre).
  Para consultas jerárquicas se construye el árbol con Zona.construir_arbol/2.
  """

  use GenServer
  alias Emergencias.{Persistencia, Zona}

  @archivo "zonas.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(codigo, nombre, nivel, afectados, padre),
    do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, nivel, afectados, padre})

  def existe?(codigo), do: GenServer.call(__MODULE__, {:existe, codigo})

  @doc "Árbol completo: lista de nodos raíz (zonas principales)."
  def arbol, do: GenServer.call(__MODULE__, :arbol)

  @doc "Nodo de una zona con todos sus descendientes."
  def subarbol(codigo), do: GenServer.call(__MODULE__, {:subarbol, codigo})

  @impl true
  def init(:ok) do
    zonas =
      @archivo
      |> Persistencia.leer(&Zona.desde_campos/1)
      |> Map.new(fn z -> {z.codigo, z} end)

    {:ok, zonas}
  end

  @impl true
  def handle_call({:registrar, codigo, nombre, nivel, afectados, padre}, _from, zonas) do
    resultado =
      if Map.has_key?(zonas, codigo) do
        {:error, "Ya existe una zona con el código #{codigo}"}
      else
        case tipo_segun_padre(zonas, padre) do
          {:ok, tipo} -> Zona.crear(codigo, nombre, tipo, nivel, afectados, padre)
          {:error, mensaje} -> {:error, mensaje}
        end
      end

    case resultado do
      {:ok, zona} ->
        nuevas = Map.put(zonas, codigo, zona)
        Persistencia.guardar(@archivo, Map.values(nuevas), &Zona.a_campos/1)
        {:reply, {:ok, zona}, nuevas}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, zonas}
    end
  end

  def handle_call({:existe, codigo}, _from, zonas) do
    {:reply, Map.has_key?(zonas, codigo), zonas}
  end

  def handle_call(:arbol, _from, zonas) do
    {:reply, Zona.construir_arbol(Map.values(zonas), "-"), zonas}
  end

  def handle_call({:subarbol, codigo}, _from, zonas) do
    arbol = Zona.construir_arbol(Map.values(zonas), "-")

    case Zona.buscar_nodo(arbol, codigo) do
      nil -> {:reply, {:error, "No existe la zona #{codigo}"}, zonas}
      nodo -> {:reply, {:ok, nodo}, zonas}
    end
  end

  # Zona principal si no tiene padre; si tiene, el tipo depende del padre.
  defp tipo_segun_padre(_zonas, "-"), do: {:ok, "zona"}

  defp tipo_segun_padre(zonas, padre) do
    case Map.fetch(zonas, padre) do
      {:ok, zona_padre} -> Zona.tipo_hijo(zona_padre.tipo)
      :error -> {:error, "No existe la zona padre #{padre}"}
    end
  end
end
