Objetivo
Permitir que un usuario emprendedor:

- se registre o inicie sesión
- verifique su email
- complete onboarding
- quede listo para operar con una Cuenta de negocio
  Este flujo soporta login manual y social.
  El acceso pleno depende de verificación de email y onboarding completo.

1. Alcance
   Incluye

- registro manual
- login manual
- login social
- verificación de email
- onboarding inicial
- creación de Cuenta de negocio
- creación del perfil Administrador principal y permisos
- sugerencia de activación de 2FA
- vínculo de nuevos métodos sociales
- manejo de sesión única
- olvidé mi contraseña
- aceptación de términos y condiciones
  No incluye
- gestión avanzada de múltiples negocios propios
- jerarquías de permisos más allá de Administrador principal
- reglas finales de bloqueo por fraude no resueltas en preguntas abiertas
- UX final de reCAPTCHA o challenge visual
- detalles de implementación de BetterAuth, JWT o base de datos

2. Actores

- Usuario nuevo
- Usuario existente
- Administrador principal
- Canguro Azul
- API de geolocalización

3. Resultado esperado
   Al finalizar el flujo:

- existe un usuario autenticable
- el email está verificado
- existe una Cuenta de negocio
- existe un perfil Administrador principal asociado a esa cuenta con sus permisos
- existe o se recupera un código de cliente en Canguro Azul
- el usuario puede entrar al producto con acceso pleno

4. Flujos
   Registro manual

- El usuario elige registrarse.
- Ingresa email y contraseña.
- Acepta términos y condiciones.
- El sistema crea el usuario en estado pendiente.
- El sistema envía verificación de email.
- El usuario verifica el email.
- El sistema obliga a completar onboarding.
- El usuario ingresa datos de negocio y facturación.
- El sistema consulta o crea el código de cliente en Canguro Azul.
- El sistema crea la primera Cuenta de negocio.
- El sistema crea el perfil Administrador principal.
- El sistema sugiere activar 2FA.
- El usuario entra con acceso pleno.
  Registro social (Google o Facebook)
- El usuario elige registrarse con un proveedor social.
- El sistema recibe la identidad del proveedor.
- Si el proveedor no entrega un email válido, el sistema solicita email manual.
- El sistema valida el email antes de continuar.
- Si no existe un usuario con ese email, crea el usuario según las reglas del producto.
- Si el flujo exige verificación adicional de email, se envía verificación y no se da acceso pleno hasta completarla.
- Luego el sistema obliga a completar onboarding.
- El usuario ingresa datos del negocio y facturación.
- El sistema consulta o crea el código de cliente en Canguro Azul.
- El sistema crea la primera Cuenta de negocio.
- El sistema crea el perfil Administrador principal.
- Al final se sugiere activar 2FA.
- El usuario entra con acceso pleno.
  Login manual
- El usuario ingresa email y contraseña.
- Si el email no está verificado, redirige a verificación.
- Si el onboarding no está completo, se redirige al onboarding.
- Si tiene 2FA activo, debe completarlo.
- Si el login ocurre en otro dispositivo, la sesión previa se invalida.
- Si el email existe pero es solo social, se le indica que ingrese con ese social o "olvidé mi contraseña"
  Login social (Google o Facebook)
- El usuario elige proveedor social.
- El sistema recibe identidad del proveedor.
- Si el proveedor no entrega email válido, se solicita manualmente y se verifica.
- El sistema busca usuario por email.
- Si encuentra usuario compatible y verificado, puede vincular el nuevo método.
- Si el usuario tiene 2FA activo, también debe completarlo.
- Si el login ocurre en otro dispositivo, la sesión previa se invalida.
  Olvidé mi contraseña
- El usuario selecciona “Olvidé mi contraseña”.
- Ingresa su email.
- El sistema envía un enlace o código de recuperación al email.
- El usuario accede al flujo de cambio de contraseña.
- Ingresa una nueva contraseña.
- El sistema valida las reglas de contraseña.
- El sistema valida que la nueva contraseña no coincida con ninguna de las últimas 5 contraseñas configuradas.
- Si pasa todas las validaciones, el sistema guarda la nueva contraseña.
- El usuario puede volver a iniciar sesión con su nueva contraseña.

5. Reglas funcionales
   Identidad

- El email es la llave maestra de identidad.
- La coincidencia es exacta.
- No se deben crear dos usuarios para el mismo email.
  Verificación
- Todo usuario nuevo queda pendiente hasta verificar email.
- Sin verificación no hay acceso pleno.
- Debe existir opción de reenvío de verificación.
  Onboarding
- El onboarding es obligatorio antes del acceso pleno.
- El onboarding crea la primera Cuenta de negocio del usuario.
- El onboarding crea el primer perfil como Administrador principal con permisos.
- El onboarding consulta o crea el código de cliente en Canguro Azul.
- El email debe estar verificado para poder hacer el onboarding.
  Roles
- El primer perfil del usuario en su negocio es Administrador principal.
- El Administrador principal tiene permisos totales dentro de su Cuenta de negocio.
  Términos y condiciones
- El registro exige aceptación de términos y condiciones.
  2FA
- 2FA es opcional en este flujo.
- Se recomienda al final del onboarding.
- Si el usuario lo activa, ningún login puede omitirlo, incluido social login.
  Sesión
- Solo puede existir una sesión activa por usuario.
- Un nuevo login invalida la sesión anterior.
  Recuperación de contraseña
- La nueva contraseña debe cumplir las reglas de seguridad definidas por el producto.
- La nueva contraseña no puede coincidir con ninguna de las últimas 5 contraseñas configuradas por el usuario.
- Si la cuenta es solo social, la recuperación de contraseña se genera una manual. Esto no afecta al login con el social.

6. Casos borde
   Email no verificado

- No permitir acceso pleno.
- Mantener estado pendiente.
- Mostrar opción de reenviar verificación.
  Social sin email real
- Solicitar email manual en la siguiente vista.
- Validarlo antes de crear o vincular cuenta y hacer onboarding.
  Nuevo social para cuenta existente
- Si el email coincide con una cuenta existente y verificada, se puede vincular.
- Solo se vincula si el método social viene verificado.
  Login manual en cuenta creada con social
- No se permite entrar con contraseña si nunca la configuró.
- Debe usar “olvidé mi contraseña” para crear una contraseña propia.
- Esto no rompe el login con socials ya vinculados.
  Cambio de email en socials
- Si el email del proveedor social cambia y deja de coincidir, ese social ya no sirve para login.
- La recuperación pasa por el flujo de olvidé mi contraseña.
  Reutilización de contraseña
- Si la nueva contraseña coincide con alguna de las últimas 5 contraseñas configuradas, el sistema la rechaza.
- Debe pedirse una contraseña distinta.
  RIF duplicado
- Si el RIF ya pertenece a otra Cuenta de negocio, rechazar.
- Mostrar mensaje genérico.
- Derivar a soporte.
  Usuario bloqueado en Zoom Core
- Si el usuario ya existe en Core y está bloqueado, mostrar aviso en onboarding.
- El mensaje debe indicar que su usuario fue limitado por Zoom.
- Se le permite el acceso a la plataforma con acciones limitadas.
  Datos y validaciones del flujo
  Onboarding
  Datos mínimos
- email
- tipo de documento
- cédula o RIF
- nombre y apellido, o razón social
- teléfono
- dirección de facturación
  Validaciones
- CI o RIF con formato válido
- celular con prefijo y 7 dígitos
- dirección de facturación obligatoria y valida
- información de geolocalización con API
  Olvidé mi contraseña
  Datos mínimos
- email
- nueva contraseña
- confirmación de nueva contraseña
  Validaciones
- el email debe pertenecer a una cuenta recuperable por contraseña
- la nueva contraseña debe cumplir la política de seguridad vigente
- la nueva contraseña no puede coincidir con ninguna de las últimas 5 contraseñas configuradas
- la confirmación debe coincidir con la nueva contraseña
  Integraciones externas
  Canguro Azul
  Se usa para:
- obtener o recuperar código de cliente
- conocer estatus del cliente si ya existe
  Datos esperados para consulta o creación:
- email
- cédula o RIF
- nombre y apellido o razón social
- teléfono
- dirección de facturación
  API de geolocalización
  Se usa para:
- completar la data de la dirección
- validar si la ubicación es válida
- validar si la ubicación es soportada por Zoom
- obtener latitud y longitud
  Datos esperados:
- ciudad
- estado
- dirección libre del usuario

7. Estados funcionales
   Usuario

- pendiente
- activo
  Onboarding
- no iniciado
- completado
  Código de cliente Canguro Azul
- no consultado
- existente
- inactivo
- activo
  Recuperación de contraseña
- no iniciada
- solicitada
- completada
- rechazada

8. Reglas de experiencia

- Mensajes cortos y accionables.
- No exponer detalle técnico de errores.
- Si falta verificación, llevar al siguiente paso claro.
- Si falta onboarding, entrar directo allí.
- Si el RIF está duplicado, mostrar mensaje genérico y soporte.
- Si el proveedor social no entrega email, pedirlo sin romper el flujo.
- Si la contraseña no cumple reglas o fue usada recientemente, mostrar mensaje claro y accionable.

9. Errores esperados

- email ya existe
- email no verificado
- credenciales inválidas
- proveedor social sin email válido
- social no verificable
- RIF ya asociado a otra Cuenta de negocio
- usuario limitado por Zoom
- fallo consultando Canguro Azul
- dirección no válida
- enlace o código de recuperación inválido o expirado
- Enlace de verificación de email invalido o expirado
- contraseña no cumple reglas
- contraseña ya usada dentro de las últimas 5

10. Criterios de aceptación

- Un usuario nuevo no puede operar sin verificar email.
- Un usuario nuevo no puede operar sin completar onboarding.
- Para poder hacer el onboarding, debe tener email verificado.
- El primer onboarding crea Cuenta de negocio y perfil Administrador principal con permisos.
- El email sigue siendo el criterio único de match.
- Un usuario existente puede vincular un nuevo social solo si el email coincide y ese social está verificado.
- Si el usuario tiene 2FA activo, cualquier login debe pedirlo.
- Un nuevo login invalida la sesión anterior.
- El registro exige aceptación de términos.
- Si el RIF ya existe en otra Cuenta de negocio, el sistema rechaza el alta.
- Si Canguro Azul ya tiene cliente, se debe reutilizar el código existente y traer su estatus.
- El sistema rechaza cualquier nueva contraseña que coincida con alguna de las últimas 5 contraseñas configuradas.

11. Preguntas abiertas

- N/A
