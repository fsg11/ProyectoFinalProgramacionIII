defmodule Emergencias.ZonaTest do
  use ExUnit.Case, async: true

  alias Emergencias.Zona

  # centro (100) -> sector3 (40) -> punto_a (10)
  #              -> sector4 (20)
  # norte  (50)
  defp zonas do
    [
      %Zona{codigo: "centro", tipo: "zona", nivel: "critico", afectados: 100, padre: "-"},
      %Zona{codigo: "sector3", tipo: "sector", nivel: "alto", afectados: 40, padre: "centro"},
      %Zona{codigo: "sector4", tipo: "sector", nivel: "alto", afectados: 20, padre: "centro"},
      %Zona{codigo: "punto_a", tipo: "punto", nivel: "medio", afectados: 10, padre: "sector3"},
      %Zona{codigo: "norte", tipo: "zona", nivel: "bajo", afectados: 50, padre: "-"}
    ]
  end

  test "construye el árbol y busca nodos de forma recursiva" do
    arbol = Zona.construir_arbol(zonas(), "-")
    assert length(arbol) == 2

    nodo = Zona.buscar_nodo(arbol, "sector3")
    assert nodo.zona.codigo == "sector3"
    assert [%{zona: %{codigo: "punto_a"}}] = nodo.hijos
    assert Zona.buscar_nodo(arbol, "no_existe") == nil
  end

  test "estadísticas acumuladas de una zona y sus sectores" do
    centro = zonas() |> Zona.construir_arbol("-") |> Zona.buscar_nodo("centro")

    assert Zona.total_afectados(centro) == 170
    assert Enum.sort(Zona.codigos_subarbol(centro)) == ["centro", "punto_a", "sector3", "sector4"]
    assert Zona.contar_por_nivel(centro) == %{"critico" => 1, "alto" => 2, "medio" => 1}
  end

  test "un punto de atención no puede tener subdivisiones" do
    assert {:ok, "sector"} = Zona.tipo_hijo("zona")
    assert {:error, _} = Zona.tipo_hijo("punto")
  end
end
