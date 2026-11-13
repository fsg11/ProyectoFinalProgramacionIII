defmodule Emergencias.Necesidad do
  @moduledoc """
  Necesidad puntual de ayuda (agua, alimentos, rescate, ...).

  Estados y transiciones válidas:

      pendiente  -> asignada (solo al asignar recursos), en_atencion, cancelada
      asignada   -> en_atencion, atendida, cancelada
      en_atencion -> atendida, cancelada
      atendida y cancelada son estados finales (no se pueden cerrar dos veces).
  """

  alias Emergencias.Util

  defstruct id: "",
            tipo: "",
            cantidad: 0,
            asignada: 0,
            prioridad: "media",
            zona: "",
            descripcion: "",
            responsable: "",
            estado: "pendiente",
            destino: "-",
            fecha: ""

  @tipos [
    "agua",
    "alimentos",
    "medicamentos",
    "primeros_auxilios",
    "refugio",
    "transporte",
    "rescate",
    "otra"
  ]

  # La prioridad se convierte en número para ORDENAR (1 se atiende primero).
  @prioridades %{"critica" => 1, "alta" => 2, "media" => 3, "baja" => 4}

  @transiciones %{
    "pendiente" => ["en_atencion", "cancelada"],
    "asignada" => ["en_atencion", "atendida", "cancelada"],
    "en_atencion" => ["atendida", "cancelada"],
    "atendida" => [],
    "cancelada" => []
  }

  def tipos, do: @tipos

  @doc "Crea una necesidad a partir de un mapa con los datos (incluido el id)."
  def crear(datos) do
    cond do
      datos.tipo not in @tipos ->
        {:error, "Tipo de necesidad inválido. Use: #{Enum.join(@tipos, ", ")}"}

      not Map.has_key?(@prioridades, datos.prioridad) ->
        {:error, "Prioridad inválida. Use: critica, alta, media o baja"}

      not is_integer(datos.cantidad) or datos.cantidad <= 0 ->
        {:error, "La cantidad requerida debe ser mayor que cero"}

      true ->
        {:ok,
         struct(
           Emergencias.Necesidad,
           Map.merge(datos, %{asignada: 0, estado: "pendiente", fecha: Util.fecha_actual()})
         )}
    end
  end

  def valor_prioridad(prioridad), do: Map.get(@prioridades, prioridad, 99)

  def faltante(necesidad), do: necesidad.cantidad - necesidad.asignada

  @doc "Ordena por prioridad (crítica primero) y, en empate, por antigüedad."
  def ordenar_por_prioridad(necesidades) do
    Enum.sort_by(necesidades, fn n -> {valor_prioridad(n.prioridad), n.fecha, n.id} end)
  end

  def abierta?(necesidad), do: necesidad.estado in ["pendiente", "asignada", "en_atencion"]

  @doc """
  Verifica si se pueden asignar `cantidad` unidades a la necesidad.
  Una necesidad atendida o cancelada nunca vuelve a consumir recursos.
  """
  def validar_asignacion(necesidad, cantidad) do
    cond do
      necesidad.estado in ["atendida", "cancelada"] ->
        {:error, "La necesidad #{necesidad.id} está #{necesidad.estado} y no puede recibir recursos"}

      necesidad.estado == "en_atencion" ->
        {:error, "La necesidad #{necesidad.id} ya está en atención"}

      cantidad > faltante(necesidad) ->
        {:error,
         "La necesidad #{necesidad.id} solo requiere #{faltante(necesidad)} unidades más"}

      true ->
        :ok
    end
  end

  def registrar_asignacion(necesidad, cantidad) do
    %{necesidad | asignada: necesidad.asignada + cantidad, estado: "asignada"}
  end

  def cambiar_estado(necesidad, nuevo_estado) do
    permitidos = Map.get(@transiciones, necesidad.estado, [])

    cond do
      permitidos == [] ->
        {:error,
         "La necesidad #{necesidad.id} ya está #{necesidad.estado}; no se puede cerrar ni modificar dos veces"}

      nuevo_estado in permitidos ->
        {:ok, %{necesidad | estado: nuevo_estado}}

      true ->
        {:error,
         "Transición inválida: #{necesidad.estado} -> #{nuevo_estado}. Permitidas: #{Enum.join(permitidos, ", ")}"}
    end
  end

  def a_campos(n) do
    [
      n.id,
      n.tipo,
      n.cantidad,
      n.asignada,
      n.prioridad,
      n.zona,
      n.descripcion,
      n.responsable,
      n.estado,
      n.destino,
      n.fecha
    ]
  end

  def desde_campos([
        id,
        tipo,
        cantidad,
        asignada,
        prioridad,
        zona,
        descripcion,
        responsable,
        estado,
        destino,
        fecha
      ]) do
    %Emergencias.Necesidad{
      id: id,
      tipo: tipo,
      cantidad: String.to_integer(cantidad),
      asignada: String.to_integer(asignada),
      prioridad: prioridad,
      zona: zona,
      descripcion: descripcion,
      responsable: responsable,
      estado: estado,
      destino: destino,
      fecha: fecha
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Necesidad do
    def to_string(n) do
      "#{n.id} [#{n.prioridad}] #{n.tipo} #{n.asignada}/#{n.cantidad} - zona #{n.zona} - " <>
        "#{n.estado} - #{n.descripcion} (reporta #{n.responsable})"
    end
  end
end
