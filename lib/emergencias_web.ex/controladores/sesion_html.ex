defmodule EmergenciasWeb.SesionHTML do
  @moduledoc "Página de inicio de sesión."

  use EmergenciasWeb, :html

  def nueva(assigns) do
    ~H"""
    <div class="pantalla-acceso">
      <div class="acceso">
        <div class="acceso-marca">
          <.logo class="grande" />
          <h1>Coordinación de emergencias</h1>
          <p>Plataforma distribuida de apoyo tras el terremoto</p>
        </div>

        <.avisos flash={@flash} />
        <div :if={@error} class="aviso aviso-error">{@error}</div>

        <form action={~p"/sesion"} method="post" class="formulario">
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <.campo etiqueta="Usuario" nombre="usuario" valor={@datos["usuario"]} requerido />
          <.campo etiqueta="Contraseña" nombre="contrasena" tipo="password" requerido />

          <details class="registro">
            <summary>¿Usuario nuevo? Datos de registro (opcional)</summary>
            <p class="nota">
              Si el usuario no existe se registra automáticamente. El primer usuario puede
              registrarse como coordinador o administrador; después, el registro solo crea
              ciudadanos y un coordinador asigna los demás roles.
            </p>
            <.campo etiqueta="Nombre completo" nombre="nombre" valor={@datos["nombre"]} />
            <.campo etiqueta="Zona" nombre="zona" valor={@datos["zona"]} ayuda="centro" />
            <.selector
              etiqueta="Tipo de usuario"
              nombre="tipo"
              opciones={Emergencias.Usuario.tipos()}
              valor={@datos["tipo"] || "ciudadano"}
            />
          </details>

          <button type="submit" class="boton boton-primario boton-bloque">Entrar</button>
        </form>
      </div>
    </div>
    """
  end
end
