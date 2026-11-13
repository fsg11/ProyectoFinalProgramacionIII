defmodule Emergencias do
  @moduledoc """
  Sistema Distribuido de Coordinación y Gestión de Emergencias.

  Atajos para iniciar el sistema desde iex:

      Emergencias.consola()                         # consola local
      Emergencias.cliente(:servidor@localhost)      # cliente de otro nodo
      Emergencias.guion("guiones/flujo_ejemplo.txt") # ejecutar un guion de comandos
  """

  def consola, do: Emergencias.Consola.iniciar()

  def cliente(nodo_servidor), do: Emergencias.Consola.conectar_remoto(nodo_servidor)

  def guion(ruta), do: Emergencias.Consola.ejecutar_guion(ruta)
end
