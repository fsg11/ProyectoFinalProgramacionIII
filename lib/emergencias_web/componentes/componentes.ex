defmodule EmergenciasWeb.Componentes do
  @moduledoc "Componentes visuales reutilizables de la interfaz web."

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :class, :string, default: nil

  @doc "Logo: una casa con un corazón (refugio y cuidado) sobre un círculo rosado."
  def logo(assigns) do
    ~H"""
    <svg class={["logo", @class]} viewBox="0 0 64 64" role="img" aria-label="Logo: casa con corazón">
      <circle cx="32" cy="32" r="31" fill="#FDCAE1" />
      <path d="M18 29 V48 a3 3 0 0 0 3 3 H43 a3 3 0 0 0 3 -3 V29 L32 17 Z" fill="#FFFFFF" />
      <rect x="40" y="15" width="5" height="10" rx="1" fill="#5B9BD5" />
      <path
        d="M12 31 L32 13 L52 31"
        fill="none"
        stroke="#5B9BD5"
        stroke-width="5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M32 46 C24 40.5 21.5 37 21.5 33.8 A5.25 5.25 0 0 1 32 31.2 A5.25 5.25 0 0 1 42.5 33.8 C42.5 37 40 40.5 32 46 Z"
        fill="#E8A2B8"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "Ilustración decorativa de una familia (dos adultos y un niño)."
  def familia(assigns) do
    ~H"""
    <svg class={["animal", @class]} viewBox="0 0 64 64" aria-hidden="true">
      <path
        d="M32 11.5 C29 9.3 27.6 8 27.6 6.6 a2.2 2.2 0 0 1 4.4 -0.6 a2.2 2.2 0 0 1 4.4 0.6 C36.4 8 35 9.3 32 11.5 Z"
        fill="#E8A2B8"
      />
      <circle cx="19" cy="21" r="7" fill="#FDE2D4" />
      <path d="M12 18.5 a7 7 0 0 1 14 0 a9 4 0 0 0 -14 0 Z" fill="#1D3A55" />
      <path d="M7 54 V41 a12 12 0 0 1 24 0 V54 Z" fill="#5B9BD5" />
      <path d="M37 22 a8 8.5 0 0 1 16 0 v9 h-16 Z" fill="#A1435F" />
      <path d="M33 54 V41 a12 12 0 0 1 24 0 V54 Z" fill="#C7B0D4" />
      <circle cx="45" cy="21" r="7" fill="#FDE2D4" />
      <path d="M38 19.5 a7 7 0 0 1 14 0 q-5 -1.5 -7 -4.5 q-2 3 -7 4.5 Z" fill="#A1435F" />
      <circle cx="32" cy="35" r="5.5" fill="#FDE2D4" />
      <path d="M23 57 V48 a9 9 0 0 1 18 0 V57 Z" fill="#8CC0A4" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "Ícono pequeño de persona (silueta); toma el color del texto."
  def icono_persona(assigns) do
    ~H"""
    <svg class={["icono-persona", @class]} viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="8" r="4" fill="currentColor" />
      <path d="M4 20.5c0-4.4 3.6-7.2 8-7.2s8 2.8 8 7.2z" fill="currentColor" />
    </svg>
    """
  end

  attr :tipo, :string, values: ~w(perro gato), required: true
  attr :class, :string, default: nil

  @doc "Ilustración decorativa de un perro o un gato (sin fondo)."
  def animal(assigns) do
    ~H"""
    <svg class={["animal", @class]} viewBox="0 0 64 64" aria-hidden="true">
      <.trazos_perro :if={@tipo == "perro"} />
      <.trazos_gato :if={@tipo == "gato"} />
    </svg>
    """
  end

  defp trazos_gato(assigns) do
    ~H"""
    <path d="M14 27 L16 8 L28 18 Z" fill="#F4A98E" />
    <path d="M50 27 L48 8 L36 18 Z" fill="#F4A98E" />
    <path d="M17.5 21.5 L18.5 12.5 L25 18 Z" fill="#FDCAE1" />
    <path d="M46.5 21.5 L45.5 12.5 L39 18 Z" fill="#FDCAE1" />
    <ellipse cx="32" cy="36" rx="19" ry="17" fill="#F4A98E" />
    <path
      d="M32 20v6M27 21l1 5M37 21l-1 5"
      stroke="#E08C6E"
      stroke-width="2"
      stroke-linecap="round"
    />
    <ellipse cx="32" cy="43" rx="9" ry="6.5" fill="#FFF6F1" />
    <ellipse cx="24.5" cy="34" rx="2.4" ry="3" fill="#1D3A55" />
    <ellipse cx="39.5" cy="34" rx="2.4" ry="3" fill="#1D3A55" />
    <circle cx="25.3" cy="33" r="0.8" fill="#FFFFFF" />
    <circle cx="40.3" cy="33" r="0.8" fill="#FFFFFF" />
    <path d="M30 39.5h4l-2 2.2z" fill="#E8A2B8" />
    <path
      d="M32 41.7c-.8 1.6-2.6 1.8-3.6.8M32 41.7c.8 1.6 2.6 1.8 3.6.8"
      stroke="#1D3A55"
      stroke-width="1.2"
      fill="none"
      stroke-linecap="round"
    />
    <path
      d="M20 41h-8M20 44l-7 2M44 41h8M44 44l7 2"
      stroke="#1D3A55"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.55"
    />
    """
  end

  defp trazos_perro(assigns) do
    ~H"""
    <ellipse cx="32" cy="35" rx="16" ry="17" fill="#FFFFFF" />
      <path d="M22 20 C14 16 8 24 9 35 C9.5 40 15 41 16.5 37 L22 24 Z" fill="#C7B0D4" />
      <path d="M42 20 C50 16 56 24 55 35 C54.5 40 49 41 47.5 37 L42 24 Z" fill="#C7B0D4" />
      <ellipse cx="38.5" cy="30" rx="5" ry="5.5" fill="#90D5FF" />
      <circle cx="25.5" cy="30.5" r="2.3" fill="#1D3A55" />
      <circle cx="38.5" cy="30.5" r="2.3" fill="#1D3A55" />
      <circle cx="26.3" cy="29.7" r="0.7" fill="#FFFFFF" />
      <circle cx="39.3" cy="29.7" r="0.7" fill="#FFFFFF" />
      <ellipse cx="32" cy="42" rx="8.5" ry="6.5" fill="#EBF3FA" />
      <path
        d="M28.5 37.5h7c.8 0 1.2 1 .6 1.6L33 42a1.4 1.4 0 0 1-2 0l-3.1-2.9c-.6-.6-.2-1.6.6-1.6z"
        fill="#1D3A55"
      />
      <path
        d="M32 42v2.2M32 44.2c-1.4 1.6-3.6 1.6-4.6.2M32 44.2c1.4 1.6 3.6 1.6 4.6.2"
        stroke="#1D3A55"
        stroke-width="1.4"
        fill="none"
        stroke-linecap="round"
      />
      <path d="M30.2 45.4q1.8 3.8 3.6 0z" fill="#E8A2B8" />
      <circle cx="21.5" cy="38" r="2.4" fill="#FDCAE1" />
      <circle cx="42.5" cy="38" r="2.4" fill="#FDCAE1" />
    """
  end

  attr :flash, :map, required: true

  def avisos(assigns) do
    ~H"""
    <div
      :for={{tipo, mensaje} <- @flash}
      :if={tipo in ["info", "error"]}
      class={["aviso", "aviso-#{tipo}"]}
      phx-click={JS.push("lv:clear-flash", value: %{key: tipo})}
      role="alert"
    >
      {mensaje}
    </div>
    """
  end

  attr :resultado, :map, default: nil

  @doc "Muestra la respuesta del último comando ejecutado."
  def resultado(assigns) do
    ~H"""
    <div :if={@resultado} id="resultado" class={["resultado", "resultado-#{@resultado.tipo}"]}>
      <div class="resultado-cabecera">
        <code>&gt; {@resultado.comando}</code>
        <button type="button" class="cerrar" phx-click="cerrar_resultado" title="Cerrar">×</button>
      </div>
      <pre>{@resultado.texto}</pre>
    </div>
    """
  end

  attr :titulo, :string, required: true
  attr :subtitulo, :string, default: nil
  attr :decoracion, :string, values: ~w(gato mascotas personas), default: "gato"

  @doc "Encabezado de página con el logo y una ilustración."
  def encabezado(assigns) do
    ~H"""
    <header class="encabezado">
      <.logo class="encabezado-logo" />
      <div class="encabezado-texto">
        <h1>{@titulo}</h1>
        <p :if={@subtitulo}>{@subtitulo}</p>
      </div>
      <div class="encabezado-ilustracion">
        <.animal :if={@decoracion == "mascotas"} tipo="perro" class="encabezado-gato" />
        <.animal :if={@decoracion in ["gato", "mascotas"]} tipo="gato" class="encabezado-gato" />
        <.familia :if={@decoracion == "personas"} class="encabezado-familia" />
      </div>
    </header>
    """
  end

  attr :titulo, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def seccion(assigns) do
    ~H"""
    <section class={["seccion", @class]}>
      <h2 :if={@titulo}>{@titulo}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :titulo, :string, required: true
  attr :valor, :any, required: true
  attr :detalle, :string, default: nil
  attr :tono, :string, default: "neutro"

  def tarjeta(assigns) do
    ~H"""
    <div class={["tarjeta", "tono-#{@tono}"]}>
      <span class="tarjeta-titulo">{@titulo}</span>
      <strong class="tarjeta-valor">{@valor}</strong>
      <span :if={@detalle} class="tarjeta-detalle">{@detalle}</span>
    </div>
    """
  end

  attr :texto, :string, required: true

  attr :icono, :string, values: ~w(casa mascota persona), default: "casa"

  @doc "Mensaje de lista vacía con un ícono."
  def vacio(assigns) do
    assigns = assign(assigns, :animal, Enum.at(~w(perro gato), :erlang.phash2(assigns.texto, 2)))

    ~H"""
    <p class="vacio">
      <.logo :if={@icono == "casa"} class="vacio-icono vacio-casa" />
      <.animal :if={@icono == "mascota"} tipo={@animal} class="vacio-icono" />
      <.icono_persona :if={@icono == "persona"} class="vacio-icono vacio-persona" />
      {@texto}
    </p>
    """
  end

  attr :valor, :integer, required: true
  attr :maximo, :integer, required: true
  attr :etiqueta, :string, default: nil

  @doc "Barra de progreso (ocupación de albergues, avance de necesidades)."
  def barra(assigns) do
    porcentaje = if assigns.maximo > 0, do: round(assigns.valor * 100 / assigns.maximo), else: 0

    nivel =
      cond do
        porcentaje >= 90 -> "alto"
        porcentaje >= 60 -> "medio"
        true -> "bajo"
      end

    assigns = assign(assigns, porcentaje: min(porcentaje, 100), nivel: nivel)

    ~H"""
    <div class="barra" title={"#{@valor} de #{@maximo}"}>
      <div class={["barra-relleno", "barra-#{@nivel}"]} style={"width: #{@porcentaje}%"}></div>
      <span class="barra-texto">{@etiqueta || "#{@valor}/#{@maximo} (#{@porcentaje}%)"}</span>
    </div>
    """
  end

  attr :texto, :string, required: true

  @doc "Etiqueta de color para estados, prioridades, niveles y roles."
  def insignia(assigns) do
    assigns = assign(assigns, :color, color(assigns.texto))

    ~H"""
    <span class={["insignia", "insignia-#{@color}"]}>{String.replace(@texto, "_", " ")}</span>
    """
  end

  defp color(texto) when texto in ~w(critica critico perdida cancelada lleno agotado), do: "rojo"
  defp color(texto) when texto in ~w(conectado entrada registro transferencia_entrada), do: "verde"
  defp color(texto) when texto in ~w(salida asignacion transferencia_salida), do: "naranja"
  defp color(texto) when texto in ~w(alta alto pendiente sin_informacion reportada), do: "naranja"
  defp color(texto) when texto in ~w(media medio en_atencion posible_coincidencia trasladada asignada),
    do: "amarillo"

  defp color(texto) when texto in ~w(baja bajo atendida resuelta reunificada entregado localizada encontrada),
    do: "verde"

  defp color(texto) when texto in ~w(en_albergue activa coordinador administrador voluntario),
    do: "azul"

  defp color(_texto), do: "gris"

  attr :etiqueta, :string, required: true
  attr :nombre, :string, required: true
  attr :tipo, :string, default: "text"
  attr :valor, :any, default: nil
  attr :requerido, :boolean, default: false
  attr :ayuda, :string, default: nil
  attr :lista, :string, default: nil
  attr :min, :any, default: nil

  def campo(assigns) do
    ~H"""
    <label class="campo">
      <span>{@etiqueta}<em :if={@requerido}>*</em></span>
      <input
        type={@tipo}
        name={@nombre}
        value={@valor}
        required={@requerido}
        placeholder={@ayuda}
        list={@lista}
        min={@min}
        autocomplete="off"
      />
    </label>
    """
  end

  attr :etiqueta, :string, required: true
  attr :nombre, :string, required: true
  attr :opciones, :list, required: true
  attr :valor, :any, default: nil
  attr :vacio, :string, default: nil

  @doc "Selector. Las opciones pueden ser textos o tuplas {texto, valor}."
  def selector(assigns) do
    ~H"""
    <label class="campo">
      <span>{@etiqueta}</span>
      <select name={@nombre}>
        <option :if={@vacio} value="">{@vacio}</option>
        <option
          :for={opcion <- @opciones}
          value={valor_opcion(opcion)}
          selected={to_string(valor_opcion(opcion)) == to_string(@valor)}
        >
          {texto_opcion(opcion)}
        </option>
      </select>
    </label>
    """
  end

  defp valor_opcion({_texto, valor}), do: valor
  defp valor_opcion(valor), do: valor
  defp texto_opcion({texto, _valor}), do: texto
  defp texto_opcion(texto), do: String.replace(to_string(texto), "_", " ")

  attr :id, :string, required: true
  attr :opciones, :list, required: true

  @doc "Lista de sugerencias para un campo de texto (<datalist>)."
  def sugerencias(assigns) do
    ~H"""
    <datalist id={@id}>
      <option :for={opcion <- @opciones} value={opcion} />
    </datalist>
    """
  end
end
