defmodule Emergencias.Consola do
  @moduledoc """
  Interfaz de texto del sistema. Tiene tres formas de uso:

    * `iniciar/0`: consola LOCAL (el usuario trabaja en el mismo nodo del servidor).
    * `conectar_remoto/1`: consola CLIENTE que envía los comandos a un nodo servidor,
      como en el ejemplo 30C-nodo-cliente del curso.
    * `ejecutar_guion/1`: ejecuta un archivo con comandos (útil para la demostración).
  """

  alias Emergencias.{Comandos, ServidorRemoto, Util}

  @doc "Consola local."
  def iniciar do
    bienvenida()
    ciclo(nil, &Comandos.ejecutar/2)
  end

  @doc "Consola cliente conectada a otro nodo, por ejemplo :servidor@localhost"
  def conectar_remoto(nodo_servidor) do
    case Node.connect(nodo_servidor) do
      true ->
        Util.mostrar("Conectado al nodo #{nodo_servidor}.", :mensaje)
        bienvenida()
        ciclo(nil, fn linea, sesion -> enviar_al_servidor(nodo_servidor, linea, sesion) end)

      false ->
        Util.mostrar("ERROR: no fue posible conectar con #{nodo_servidor}.", :error)

      :ignored ->
        Util.mostrar("ERROR: este nodo no se inició como nodo distribuido (use --sname).", :error)
    end
  end

  @doc "Ejecuta, en orden, los comandos de un archivo de texto (las líneas con # se ignoran)."
  def ejecutar_guion(ruta) do
    ruta
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn linea -> linea == "" or String.starts_with?(linea, "#") end)
    |> Enum.reduce(nil, fn linea, sesion ->
      Util.mostrar("\n> #{linea}", :mensaje)
      {respuesta, nueva_sesion} = Comandos.ejecutar(linea, sesion)
      Util.mostrar(respuesta, :mensaje)
      nueva_sesion
    end)

    :ok
  end

  defp ciclo(sesion, ejecutar) do
    case IO.gets(indicador(sesion)) do
      :eof ->
        :ok

      {:error, _razon} ->
        :ok

      linea ->
        linea = String.trim(linea)

        if linea in ["exit", "salir"] do
          if sesion != nil, do: ejecutar.("disconnect", sesion)
          Util.mostrar("Programa finalizado.", :mensaje)
        else
          {respuesta, nueva_sesion} = ejecutar.(linea, sesion)
          if respuesta != "", do: Util.mostrar(respuesta, :mensaje)
          ciclo(nueva_sesion, ejecutar)
        end
    end
  end

  # Envía el comando al servidor remoto y espera la respuesta (paso de mensajes).
  defp enviar_al_servidor(nodo_servidor, linea, sesion) do
    send({ServidorRemoto.nombre_servicio(), nodo_servidor}, {self(), {:comando, linea, sesion}})

    receive do
      {:respuesta, texto, nueva_sesion} -> {texto, nueva_sesion}
    after
      10_000 -> {"ERROR: el servidor no respondió a tiempo.", sesion}
    end
  end

  defp indicador(nil), do: "\nemergencias> "
  defp indicador(sesion), do: "\n#{sesion.usuario}@emergencias> "

  defp bienvenida do
    Util.mostrar(
      """
      ==================================================
       Sistema Distribuido de Gestión de Emergencias
      ==================================================
      Escriba help para ver los comandos y exit para salir.
      """,
      :mensaje
    )
  end
end
