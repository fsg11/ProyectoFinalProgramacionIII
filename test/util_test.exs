defmodule Emergencias.UtilTest do
  use ExUnit.Case, async: true
  doctest Emergencias.Util

  alias Emergencias.Util

  test "separar_palabras respeta el texto entre comillas" do
    assert Util.separar_palabras(~s(send_family_message 1094 "Estoy bien, en el albergue")) ==
             ["send_family_message", "1094", "Estoy bien, en el albergue"]

    assert Util.separar_palabras("   list_needs   zona=centro  ") == ["list_needs", "zona=centro"]
    assert Util.separar_palabras("") == []
  end

  test "entero valida números negativos y textos" do
    assert Util.entero("20", "cantidad") == {:ok, 20}
    assert {:error, _} = Util.entero("-5", "cantidad")
    assert {:error, _} = Util.entero("abc", "cantidad")
    assert {:error, _} = Util.entero_positivo("0", "cantidad")
  end

  test "normalizar quita tildes y mayúsculas" do
    assert Util.normalizar(" Crítica ") == "critica"
  end
end
