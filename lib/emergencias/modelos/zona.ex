defmodule Emergencias.Zona do
  @moduledoc """
  Zonas afectadas organizadas jerárquicamente: zona -> sector -> punto de atención.

  En memoria y en el archivo cada zona se guarda en una lista plana, donde cada
  elemento conoce el código de su `padre` ("-" si es una zona principal).
  Para consultar estadísticas se construye un ÁRBOL con nodos de la forma:

      %{zona: %Zona{}, hijos: [nodo, nodo, ...]}

  Varias funciones de este módulo son recursivas sobre ese árbol.
  """

  defstruct codigo: "", nombre: "", tipo: "zona", nivel: "medio", afectados: 0, padre: "-"

  @niveles ["critico", "alto", "medio", "bajo"]

  def niveles, do: @niveles

  def crear(codigo, nombre, tipo, nivel, afectados, padre) do
    cond do
      codigo == "" ->
        {:error, "El código de la zona es obligatorio"}

      nivel not in @niveles ->
        {:error, "Nivel de afectación inválido. Use: #{Enum.join(@niveles, ", ")}"}

      afectados < 0 ->
        {:error, "El número de personas afectadas no puede ser negativo"}

      true ->
        {:ok,
         %Emergencias.Zona{
           codigo: codigo,
           nombre: nombre,
           tipo: tipo,
           nivel: nivel,
           afectados: afectados,
           padre: padre
         }}
    end
  end

  @doc "Tipo que tendrá un hijo según el tipo del padre."
  def tipo_hijo("zona"), do: {:ok, "sector"}
  def tipo_hijo("sector"), do: {:ok, "punto"}
  def tipo_hijo(_tipo), do: {:error, "Un punto de atención no puede tener subdivisiones"}

  @doc """
  (Recursiva) Construye el árbol a partir de la lista plana de zonas.
  Toma las zonas cuyo padre es `padre` y, para cada una, construye
  recursivamente sus hijos.
  """
  def construir_arbol(zonas, padre) do
    zonas
    |> Enum.filter(fn zona -> zona.padre == padre end)
    |> Enum.sort_by(fn zona -> zona.codigo end)
    |> Enum.map(fn zona -> %{zona: zona, hijos: construir_arbol(zonas, zona.codigo)} end)
  end

  @doc "(Recursiva) Busca un nodo por código dentro de una lista de nodos."
  def buscar_nodo([], _codigo), do: nil
  def buscar_nodo([%{zona: %{codigo: codigo}} = nodo | _resto], codigo), do: nodo

  def buscar_nodo([%{hijos: hijos} | resto], codigo) do
    case buscar_nodo(hijos, codigo) do
      nil -> buscar_nodo(resto, codigo)
      nodo -> nodo
    end
  end

  @doc "(Recursiva) Suma las personas afectadas del nodo y de todos sus descendientes."
  def total_afectados(%{zona: zona, hijos: hijos}), do: zona.afectados + total_afectados_lista(hijos)

  defp total_afectados_lista([]), do: 0

  defp total_afectados_lista([nodo | resto]),
    do: total_afectados(nodo) + total_afectados_lista(resto)

  @doc "(Recursiva) Lista los códigos del nodo y de todos sus descendientes."
  def codigos_subarbol(nodo), do: codigos_lista([nodo])

  defp codigos_lista([]), do: []

  defp codigos_lista([%{zona: zona, hijos: hijos} | resto]),
    do: [zona.codigo | codigos_lista(hijos ++ resto)]

  @doc "(Recursiva) Cuenta cuántos nodos hay por nivel de afectación."
  def contar_por_nivel(%{zona: zona, hijos: hijos}) do
    Enum.reduce(hijos, %{zona.nivel => 1}, fn hijo, acumulado ->
      Map.merge(acumulado, contar_por_nivel(hijo), fn _nivel, a, b -> a + b end)
    end)
  end

  @doc "(Recursiva) Representa el árbol como texto con sangría."
  def formatear(%{zona: zona, hijos: hijos}, sangria) do
    linea = String.duplicate("   ", sangria) <> "- #{zona}"
    Enum.join([linea | Enum.map(hijos, fn hijo -> formatear(hijo, sangria + 1) end)], "\n")
  end

  def a_campos(z), do: [z.codigo, z.nombre, z.tipo, z.nivel, z.afectados, z.padre]

  def desde_campos([codigo, nombre, tipo, nivel, afectados, padre]) do
    %Emergencias.Zona{
      codigo: codigo,
      nombre: nombre,
      tipo: tipo,
      nivel: nivel,
      afectados: String.to_integer(afectados),
      padre: padre
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Zona do
    def to_string(z),
      do: "#{z.tipo} #{z.codigo} - #{z.nombre} [nivel #{z.nivel}] afectados: #{z.afectados}"
  end
end
