defmodule EmergenciasWeb.Acciones do
  @moduledoc "Funciones comunes de las páginas web."

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  alias Emergencias.{Comandos, Usuario, Zona, Zonas}

  @doc "Ejecuta un comando con la sesión del usuario y guarda la respuesta en @resultado."
  def ejecutar(socket, partes) do
    linea = armar_linea(partes)
    {texto, nueva_sesion} = Comandos.ejecutar(linea, socket.assigns.sesion)

    if nueva_sesion == nil do
      socket |> put_flash(:error, texto) |> redirect(to: "/")
    else
      tipo = tipo_resultado(texto)

      socket
      |> assign(:resultado, %{comando: linea, texto: String.trim_trailing(texto), tipo: tipo})
      |> then(fn s -> if tipo == :exito, do: update(s, :version, &((&1 || 0) + 1)), else: s end)
    end
  end

  @doc """
  Convierte una lista de partes en una línea de comando.

      iex> EmergenciasWeb.Acciones.armar_linea(["register_need", "agua", "30", "Punto 3", "", ""])
      ~s(register_need agua 30 "Punto 3")
  """
  def armar_linea(partes) do
    partes
    |> Enum.map(fn parte -> parte |> to_string() |> String.replace("\"", "'") |> String.trim() end)
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
    |> Enum.map_join(" ", fn parte ->
      if parte == "" or String.contains?(parte, " "), do: ~s("#{parte}"), else: parte
    end)
  end

  @errores ["Error", "Permiso denegado", "Uso:", "Comando desconocido", "Sesión no válida", "Debe conectarse"]

  @doc "Clasifica la respuesta de un comando para mostrarla con el color adecuado."
  def tipo_resultado(texto) do
    cond do
      String.starts_with?(texto, @errores) -> :error
      String.contains?(texto, "rechazada") -> :error
      true -> :exito
    end
  end

  @doc "Indica si el usuario tiene el nivel que exige el comando."
  def puede?(usuario, comando) do
    case Comandos.nivel_requerido(comando) do
      nil -> false
      nivel -> Usuario.nivel(usuario.tipo) >= nivel
    end
  end

  @doc "Códigos de todas las zonas, sectores y puntos (recorre el árbol)."
  def codigos_zona do
    Zonas.arbol() |> Enum.flat_map(&Zona.codigos_subarbol/1)
  end

  @doc "Lee un parámetro de formulario como texto (vacío si no viene)."
  def param(parametros, clave), do: parametros |> Map.get(clave, "") |> to_string() |> String.trim()
end
