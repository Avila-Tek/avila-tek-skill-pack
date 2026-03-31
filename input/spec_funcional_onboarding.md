SPEC FUNCIONAL
Épica: Onboarding Digital del Cliente
R4 – Sistema de Solicitud de Crédito
Proyecto
R4 – Sistema de Solicitud de Crédito	Responsable
Avila Tek / Preventas	Estado
Borrador	Fecha
Marzo 2026



1. Resumen Ejecutivo y Objetivo
El presente documento especifica el comportamiento funcional de la épica de Onboarding Digital del Cliente en la plataforma web de R4. Esta épica cubre el proceso completo desde que un usuario ingresa por primera vez a la plataforma hasta que su perfil financiero queda conformado y listo para evaluación.

•	Objetivo de la épica: Digitalizar y simplificar el proceso de registro, verificación de identidad y perfilamiento financiero del cliente (persona natural o jurídica) de R4, reduciendo tiempos operativos y la intervención manual previa a la liquidación de un crédito.
•	Problema que resuelve: Actualmente el trámite de solicitar un crédito involucra mucho tiempo de ambas partes previo a la liquidación de los fondos. El proceso existente no es un flujo digitalizado y requiere pasos manuales tanto del personal del banco como del cliente.
•	Dependencias críticas: Proveedor de correo electrónico (notificaciones OTP); Procert (certificados electrónicos y OTP, V2); datos de parámetros financieros suministrados por R4; reglas de negocio y tabla de rangos de crédito aprobadas por R4.
•	Métricas de éxito (KPIs): Tasa de completitud del onboarding (registro exitoso / intentos iniciados); tiempo promedio de registro; tasa de abandono por paso; porcentaje de solicitudes con pre-análisis completado exitosamente.


2. Alcance (In & Out)
Incluido en la épica
•	Onboarding digital del cliente con flujo de 4 pasos: tipo de cliente, tipo de persona, datos básicos y creación de contraseña.
•	Verificación de identidad mediante código OTP de 6 dígitos enviado al correo electrónico registrado.
•	Creación de contraseña segura con validación en tiempo real de requisitos.
•	Perfilamiento de crédito (Fase 2): datos personales complementarios, actividad económica, declaración de ingresos y otros ingresos.
•	Carga de recaudos mínimos requeridos: Documento de identidad, RIF, Certificación de ingresos, Estado de cuenta (últimos 3 meses).
•	Pre-análisis automatizado con generación de propuesta preliminar de condiciones de crédito (monto, tasa, plazo).
•	Página de resultado con detalle de pre-aprobación y decisión del usuario de continuar o no.
•	Notificaciones automáticas al cliente por correo electrónico en etapas clave del proceso.
•	Opción de 'Completar después' en los pasos del flujo, permitiendo guardar progreso parcial.

Fuera de alcance de la épica
•	Apertura formal de cuenta bancaria (proceso externo existente en R4).
•	Procesos KYC/Onboarding bancario completo.
•	Integración con Procert para firma electrónica embebida (V2).
•	Integración con Core Bancario COBIS para sincronizar información de cliente o crédito (V2).
•	Integración con Docuware para gestión documental del expediente (V2 / definir punto de corte).
•	Autenticación de clientes mediante Directorio Activo (SSO) – exclusivo para usuarios internos del banco.
•	Aplicación móvil (iOS / Android).
•	Notificaciones por canales adicionales al correo electrónico (SMS, WhatsApp, etc.).
•	Chat con capacidades de bot inteligente o inteligencia artificial.
•	Gestión de pagos, abonos o pasarelas de pago.


3. Matriz de Actores y Roles
Usuarios Finales (Externos)
•	Persona Natural: Cliente individual que inicia un proceso de solicitud de crédito a través de la plataforma web de R4. Puede ser cliente fijo o cliente nuevo del banco.
•	Persona Jurídica: Empresa o entidad legal que inicia una solicitud de crédito. El flujo de datos puede diferir en campos específicos según el tipo de persona seleccionado.
•	Firmantes terceros: Personas que no son clientes del banco pero que pueden intervenir en la firma de documentos cuando aplique. Su participación formal está contemplada para V2 mediante Procert.

Sistemas Internos
•	Plataforma Web Cliente: Interfaz digital principal del onboarding. Gestiona el flujo paso a paso, valida datos en tiempo real y presenta la propuesta preliminar de crédito.
•	Base de Datos de Prospectos: Repositorio donde se almacena la información de clientes que no han concretado el crédito. Se mantiene separada de la base de clientes formales del banco para evitar duplicidad. En V1 la consolidación de clientes aprobados se realiza manualmente.
•	Motor de Pre-análisis: Componente del sistema que evalúa la información financiera declarada por el cliente contra la tabla de parámetros suministrada por R4, generando una referencia preliminar de condiciones de crédito (monto, tasa, plazo estimado). No constituye una aprobación formal.
•	API Principal (Go): Backend del sistema. Gestiona la lógica de negocio, validaciones, almacenamiento y comunicación entre componentes. Tecnología base: Go (según especificaciones de R4).

Servicios de Terceros
•	Proveedor de Correo Electrónico: Servicio externo utilizado para el envío del código OTP de verificación al email del cliente durante el registro (Fase 1, Paso 3.1). También se usa para notificaciones automáticas en etapas clave del proceso.
•	Procert: Proveedor de certificados electrónicos y firma digital. En V1 se contempla para el envío del OTP de verificación de identidad. La integración completa para firma de documentos de crédito embebida en la plataforma está contemplada para V2.
•	Directorio Activo / SSO: Sistema de autenticación único del banco utilizado exclusivamente para el acceso de usuarios internos a la plataforma administrativa (Backoffice). No aplica para clientes externos en la plataforma cliente.


4. Reglas de Negocio Aplicables a la Épica
•	RN-01: El onboarding bancario formal (alta como cliente del banco) es un proceso externo y previo, no gestionado por esta plataforma.
•	RN-02: La solución no reemplaza ni modifica los sistemas core del banco (COBIS).
•	RN-03: Toda la información sensible de clientes y prospectos debe residir on-premise dentro de Venezuela, conforme a regulación de SUDEBAN.
•	RN-04: La plataforma incorpora trazabilidad end-to-end: registra accesos, acciones, decisiones y cambios de estado para fines de auditoría y cumplimiento regulatorio.
•	RN-05: Los clientes que no concretan el crédito se mantienen en la base de datos de prospectos segmentada; no se migran a la base de clientes formales del banco.
•	RN-06: Una vez que un cliente formaliza el crédito, su registro se migra a la base de datos de clientes del banco (en V1 de forma manual), evitando duplicidad de información.
•	RN-07: El pre-análisis automatizado genera únicamente una referencia preliminar de condiciones; no constituye aprobación formal del crédito.
•	RN-08: La decisión final del crédito recae en el Comité de Crédito, el cual opera exclusivamente con expediente completo.
•	RN-09: Las reglas de negocio, roles, permisos, recaudos, plantillas documentales y autonomías del Comité serán definidas y validadas por R4, y configuradas en la plataforma conforme a dicho marco.
•	RN-10: La tabla de parámetros financieros utilizada para el pre-análisis de crédito será suministrada por R4.
•	RN-11: No se contemplan automatizaciones para cambios de estatus de la solicitud de crédito en V1.
•	RN-12: El cliente puede pausar el proceso usando la opción 'Completar después' en pasos habilitados; el sistema debe preservar los datos ingresados hasta ese punto.
•	RN-13: La contraseña del cliente debe cumplir los siguientes requisitos simultáneamente: mínimo 1 número, mínimo 1 letra mayúscula, mínimo 1 carácter especial, mínimo 1 letra minúscula, longitud entre 8 y 32 caracteres, y ambas contraseñas ingresadas deben coincidir.
•	RN-14: El código OTP de verificación es de 6 dígitos, enviado al correo electrónico registrado. El sistema debe ofrecer la opción 'Reenviar código'.


5. Definición de Flujos (Step-by-Step)
Flujo A: Registro e Identificación (Fase 1)
Descripción: Cubre el proceso de registro inicial del cliente: validación de tipo de usuario, captura de datos básicos, verificación de identidad por OTP y creación de contraseña de acceso seguro a la plataforma R4.

•	Entrada: El usuario accede a la plataforma web de R4 (pantalla de bienvenida) y selecciona iniciar el proceso de solicitud de crédito digital.
•	Proceso del Sistema: El sistema presenta el wizard de registro en 4 pasos secuenciales: (1) verificación de tipo de cliente, (2) tipo de persona, (3) captura de datos personales básicos y envío de OTP, y (4) creación de contraseña. El sistema valida en tiempo real cada campo. Tras verificación OTP exitosa, el sistema confirma identidad y habilita la creación de contraseña.
•	Bloqueos Funcionales: No es posible avanzar del Paso 1 sin seleccionar tipo de cliente. No es posible avanzar del Paso 2 sin seleccionar tipo de persona. No es posible avanzar del Paso 3 sin completar todos los campos obligatorios y verificar el código OTP. No es posible completar el registro sin cumplir todos los requisitos de contraseña.
•	Integración: En el Paso 3.1: el sistema invoca al proveedor de correo electrónico para el envío del OTP de 6 dígitos al email ingresado. La validación del código OTP se realiza en el backend.
•	Resultado final: El cliente queda registrado en la plataforma con credenciales válidas. Su registro es almacenado como prospecto en la base de datos. El sistema redirige automáticamente al inicio de la Fase 2 (perfilamiento de crédito).

Detalle de Pasos — Flujo A
Paso 1 de 4 — ¿Ya eres cliente de R4?
•	El sistema muestra dos opciones de selección visual: 'Soy cliente fijo' y 'Soy cliente nuevo'.
•	Ambas opciones conducen al Paso 2; el sistema registra la selección para segmentación interna.

Paso 2 de 4 — Tipo de persona
•	El sistema presenta dos opciones: 'Persona natural' y 'Persona jurídica'.
•	La selección condiciona los campos del Paso 3 y el flujo subsiguiente de perfilamiento.
•	Se habilita la opción 'Completar después' en este paso.

Paso 3 de 4 — Información personal básica
•	El sistema solicita los campos de datos básicos. Todos los campos son obligatorios.
•	Al confirmar los datos, el sistema envía automáticamente el código OTP al correo ingresado.
•	Se habilita la opción 'Completar después' y el botón 'Borrar datos ingresados'.

Paso 3.1 — Verificación OTP
•	El sistema muestra un formulario de 6 campos individuales para el código OTP.
•	El email destino se muestra parcialmente enmascarado en pantalla (ej: j***@gmail.com).
•	El usuario dispone de los botones 'Regresar' (vuelve al Paso 3) y 'Continuar' (valida OTP).
•	La opción 'Reenviar código' está disponible para solicitar un nuevo OTP.

Paso 4 de 4 — Crea tu contraseña
•	El sistema muestra dos campos: 'Contraseña' y 'Confirmar contraseña'.
•	Los requisitos se validan en tiempo real y se indican visualmente al usuario (check/error).
•	Los 6 requisitos mostrados son: (1) al menos 1 número, (2) al menos 1 letra mayúscula, (3) al menos 1 carácter especial, (4) al menos 1 letra minúscula, (5) longitud entre 8 y 32 caracteres, (6) ambas contraseñas coinciden.

Detalles del Flujo A
•	Reglas funcionales: Si el usuario selecciona 'Soy cliente fijo' en Paso 1, el sistema debe validar si ya existe un registro activo con la cédula o email ingresados en Paso 3 para evitar duplicidad. La dirección de correo electrónico ingresada en Paso 3 es el identificador principal para el envío de OTP y futuras notificaciones.
•	Casos bordes: Email ya registrado en el sistema: el sistema debe notificar al usuario e impedir la creación de un duplicado. OTP incorrecto: el sistema debe mostrar error e invitar a reintentar o reenviar código. OTP expirado: el sistema debe ofrecer la opción 'Reenviar código'. Correo no recibido: el usuario puede solicitar reenvío. Contraseña que no cumple requisitos: el botón de avance permanece deshabilitado hasta cumplir todos los criterios. Usuario cierra el navegador durante el flujo: el sistema debe poder recuperar el progreso hasta el punto guardado (si usó 'Completar después').

Datos y Validaciones del Flujo A — Paso 3
Campo	Tipo	Obligatorio	Regla / Validación
Nombre	Texto	Sí	Mínimo 2 caracteres. Solo letras y espacios.
Apellido	Texto	Sí	Mínimo 2 caracteres. Solo letras y espacios.
Cédula	Numérico	Sí	Prefijo tipo (V/E) + número. Formato: V-12.345.678. Único en el sistema.
Correo electrónico	Email	Sí	Formato válido de email. Único en el sistema. Usado para OTP.
Teléfono	Numérico	Sí	Prefijo país (+58 Venezuela). Formato: (000) 000-0000.
Código OTP	Numérico	Sí	6 dígitos. Válido por tiempo limitado. [PENDIENTE: tiempo de expiración]
Contraseña	Texto	Sí	8-32 chars. Mínimo: 1 número, 1 mayúscula, 1 especial, 1 minúscula.
Confirmar contraseña	Texto	Sí	Debe ser idéntica al campo Contraseña.

•	Estados funcionales del Flujo A: Registro iniciado (Paso 1 completado) → Tipo de persona seleccionado → Datos básicos ingresados → Código OTP enviado → Código OTP verificado → Contraseña creada → Registro completado (Fase 1).


Flujo B: Perfilamiento y Pre-Análisis de Crédito (Fase 2)
Descripción: Cubre el proceso de completar el perfil del cliente, declarar actividad económica e ingresos, cargar documentos de soporte y recibir el resultado del pre-análisis automatizado de crédito.

•	Entrada: El cliente ha completado el registro (Flujo A) y es redirigido automáticamente al inicio de la Fase 2. También puede ingresar desde su sesión activa si guardó progreso con 'Completar después'.
•	Proceso del Sistema: El sistema presenta el wizard de perfilamiento en 5 pasos: (1) perfil personal completo, (2) actividad económica, (3) declaración de ingresos (principal y otros), (4) carga de documentos requeridos, y (5) resumen, aceptación de T&C y resultado del pre-análisis. El motor de pre-análisis evalúa los datos declarados contra la tabla de parámetros de R4 y genera una propuesta preliminar.
•	Bloqueos Funcionales: No es posible avanzar del Paso 1 sin completar todos los campos obligatorios de perfil y dirección. No es posible avanzar del Paso 2 sin seleccionar condición laboral y completar los campos asociados según la condición seleccionada. No es posible avanzar del Paso 3 sin indicar el rango de ingreso mensual principal. Los documentos obligatorios (Documento de identidad, RIF, Certificación de ingresos) deben ser cargados para avanzar del Paso 4.
•	Integración: Paso 4 (carga de documentos): el sistema almacena los archivos en el repositorio de almacenamiento on-premise de R4. La integración con Docuware como repositorio oficial del expediente está contemplada para V2. El motor de pre-análisis consulta la tabla de parámetros configurada por R4 para generar la propuesta preliminar.
•	Resultado final: El sistema muestra al cliente la pantalla de pre-aprobación con el detalle de la oferta preliminar (cuota mensual estimada, plazo, monto pre-aprobado, tasa estimada y total estimado a pagar). El cliente decide si continúa o no con el proceso formal. El estado de la solicitud queda registrado para seguimiento.

Detalle de Pasos — Flujo B
Paso 1 de 5 — Completa tu perfil
•	Sección 'Datos básicos': los campos Nombre, Apellido, Cédula, Correo y Teléfono vienen pre-populados desde la Fase 1 y no son editables en este paso.
•	Sección 'Datos complementarios': Fecha de nacimiento, Estado civil, Profesión u ocupación, Personas a cargo.
•	Sección 'Dirección': Estado, Ciudad, Dirección (texto libre).
•	Se habilita la opción 'Completar después' y el botón 'Borrar datos ingresados'.

Paso 2 de 5 — Actividad económica
•	El sistema solicita la condición laboral del cliente mediante radio buttons: Empleado, Independiente, Comerciante, Jubilado, Otro.
•	Según la condición seleccionada, el sistema despliega campos adicionales condicionados:
◦	Empleado: Empresa, Antigüedad laboral (dropdown), Tipo de ingreso principal (dropdown: 'Sueldo fijo' y otros [PENDIENTE: opciones completas]), Frecuencia de ingreso (dropdown: Mensual y otros [PENDIENTE: opciones completas]).
◦	Independiente / Comerciante / Jubilado / Otro: [PENDIENTE: Definir campos adicionales específicos para cada condición laboral]
•	Se habilita la opción 'Completar después' y el botón 'Borrar datos ingresados'.

Paso 3 de 5 — Declaración de ingresos
•	Sub-paso A — Ingreso mensual principal: el sistema muestra rangos de selección única mediante radio buttons:
◦	Menos de $300
◦	Entre $300 y $600
◦	Entre $601 y $1.000
◦	Entre $1.001 y $2.000
◦	Más de $2.000
•	Sub-paso B — Otros ingresos mensuales: el sistema muestra rangos de selección única:
◦	Entre $100 y $300
◦	Entre $301 y $600
◦	Entre $601 y $1.000
◦	Más de $1.000
◦	No tengo otros ingresos adicionales
•	[PENDIENTE: Confirmar si existen pasos adicionales del Paso 3 para gastos, compromisos financieros, monto solicitado [$100-$10.000], plazo [30/60/90 días] y propósito del crédito según Epic Description provista.]

Paso 4 de 5 — Carga de documentos
•	El sistema presenta áreas de carga individual por tipo de documento (drag and drop o click to upload).
•	Formatos aceptados: SVG, PNG, JPG, GIF. Tamaño máximo: 800×400 px.
•	Documentos obligatorios (*): Documento de identidad, RIF, Certificación de ingresos.
•	Documento opcional: Estado de cuenta últimos 3 meses.
•	Se habilita la opción 'Completar después'.

Paso 5 de 5 — Resumen y resultado del pre-análisis
•	El sistema ejecuta el motor de pre-análisis con los datos declarados y muestra la pantalla de resultado.
•	Pantalla de pre-aprobación incluye: mensaje de confirmación, advertencia de sujeto a validación formal, y bloque 'Detalle de la oferta' con: Cuota mensual estimada, plazo (en días), Monto pre-aprobado, Tasa estimada (%), Total estimado a pagar.
•	El cliente dispone de dos acciones: 'No continuar ahora' (pausa el proceso) o 'Sí, continuar' (avanza a la fase formal de solicitud).
•	[PENDIENTE: Definir contenido de la pantalla de Términos y Condiciones y el flujo de aceptación requerido antes del resultado del pre-análisis.]

Detalles del Flujo B
•	Reglas funcionales: Los datos pre-poblados del Paso 1 (provenientes de Fase 1) no pueden ser modificados en este paso; si el cliente necesita corregirlos, debe existir un mecanismo definido. El motor de pre-análisis opera únicamente con la tabla de parámetros configurada por R4 (suministro pendiente de R4). La propuesta preliminar mostrada no es vinculante ni constituye aprobación formal. El sistema debe registrar la decisión del cliente (continuar / no continuar) con trazabilidad de auditoría.
•	Casos bordes: Cliente que interrumpe el flujo y regresa posteriormente: debe poder retomar desde el paso donde lo dejó. Fallo en la carga de archivo (formato no soportado, tamaño excedido): el sistema muestra error específico y permite reintento. Motor de pre-análisis sin tabla de parámetros configurada: el sistema no debe mostrar valores erróneos; debe gestionar el estado de forma controlada. Cliente selecciona 'No continuar ahora': el sistema preserva todos los datos ingresados y marca la solicitud como en pausa.

Datos y Validaciones del Flujo B — Paso 1
Campo	Tipo	Obligatorio	Regla / Validación
Nombre / Apellido / Cédula / Correo / Teléfono	Varios	Sí	Pre-populados. Solo lectura en este paso.
Fecha de nacimiento	Fecha	Sí	Formato: dd/mm/aaaa. No puede ser fecha futura. Edad mínima: [PENDIENTE].
Estado civil	Select	Sí	Opciones: [PENDIENTE: confirmar lista completa con R4].
Profesión u ocupación	Select	Sí	Opciones: [PENDIENTE: confirmar lista completa con R4].
Personas a cargo	Entero	Sí	Número entero >= 0.
Estado (dirección)	Select	Sí	Lista de estados de Venezuela. [PENDIENTE: catálogo].
Ciudad	Select	Sí	Dependiente del Estado seleccionado. [PENDIENTE: catálogo].
Dirección	Texto	Sí	Texto libre. Mínimo 10 caracteres.

Datos y Validaciones del Flujo B — Paso 2 (Empleado)
Campo	Tipo	Obligatorio	Regla / Validación
Condición laboral	Radio	Sí	Opciones: Empleado, Independiente, Comerciante, Jubilado, Otro.
Empresa	Texto	Sí (si Empleado)	Nombre de la empresa. Mínimo 2 caracteres.
Antigüedad laboral	Select	Sí (si Empleado)	Opciones con rangos de tiempo: 'Entre 1 y 3 años' y otras [PENDIENTE: lista completa].
Tipo de ingreso principal	Select	Sí (si Empleado)	Opciones incluyen 'Sueldo fijo'. [PENDIENTE: lista completa].
Frecuencia de ingreso	Select	Sí (si Empleado)	Opciones incluyen 'Mensual'. [PENDIENTE: lista completa].

Datos y Validaciones del Flujo B — Paso 4 (Documentos)
Campo	Tipo	Obligatorio	Regla / Validación
Documento de identidad	Archivo	Sí	Formatos: SVG, PNG, JPG, GIF. Máx.: 800×400 px.
RIF	Archivo	Sí	Formatos: SVG, PNG, JPG, GIF. Máx.: 800×400 px.
Certificación de ingresos	Archivo	Sí	Formatos: SVG, PNG, JPG, GIF. Máx.: 800×400 px.
Estado de cuenta últimos 3 meses	Archivo	No	Formatos: SVG, PNG, JPG, GIF. Máx.: 800×400 px.

•	Estados funcionales del Flujo B: Perfilamiento iniciado → Perfil básico completado → Actividad económica completada → Ingresos declarados → Documentos cargados → Pre-análisis ejecutado → Propuesta preliminar generada → Cliente acepta continuar (→ solicitud formal) / Cliente no continúa (→ registro en pausa).


6. Integraciones Externas
Proveedor de Correo Electrónico (Notificaciones)
•	Se usa para: Flujo A (Paso 3.1): envío del código OTP de verificación de identidad al email del cliente. Flujo B y proceso general: notificaciones automáticas al cliente sobre avances, acciones pendientes y resultados del proceso.
•	Datos esperados (entrada): Dirección de correo electrónico del destinatario, tipo de notificación (OTP / estado de solicitud), contenido del mensaje. Código OTP de 6 dígitos generado por el sistema.
•	Datos esperados (salida): Confirmación de envío exitoso o código de error. El sistema registra el evento de envío con trazabilidad.
•	Restricción: Toda la información enviada y almacenada debe cumplir con los requisitos on-premise de SUDEBAN para datos sensibles de clientes.
•	Proveedor específico: [PENDIENTE: Confirmar proveedor de correo/mensajería con R4. Reglas de notificación por definir.]

Procert (Certificados Electrónicos y OTP)
•	Se usa para: V1: Verificación de identidad del cliente mediante OTP en el Paso 3.1 del Flujo A. V2 (fuera de alcance): firma electrónica con certificado embebida en la plataforma para clientes y firmantes terceros.
•	Datos esperados (entrada): Datos de identidad del cliente para generación/validación del código OTP. [PENDIENTE: especificaciones de los endpoints de API de Procert para OTP].
•	Datos esperados (salida): Confirmación de código OTP válido o inválido.
•	Restricción de V1: En V1 no se implementa la integración para firma electrónica embebida ni la verificación de vigencia de certificados para firmantes no clientes. Esto está contemplado para V2.
•	APIs disponibles: Existen APIs disponibles de Procert para certificados electrónicos y firma digital, según validación del equipo de Preventas.

Almacenamiento de Archivos (Documentos del Cliente)
•	Se usa para: Paso 4 del Flujo B: almacenamiento on-premise de los documentos cargados por el cliente (Documento de identidad, RIF, Certificación de ingresos, Estado de cuenta).
•	Datos esperados (entrada): Archivo en formato SVG, PNG, JPG o GIF. Máximo 800×400 px. Metadatos: tipo de documento, ID del cliente, timestamp de carga.
•	Datos esperados (salida): URL o referencia interna del archivo almacenado. Confirmación de carga exitosa.
•	Restricción SUDEBAN: Los documentos y toda la información sensible de clientes/prospectos deben residir on-premise dentro de Venezuela, conforme a regulación de SUDEBAN.
•	Docuware (V2): La integración con Docuware como repositorio oficial del expediente documental está contemplada para V2. El punto de corte entre el almacenamiento interno y Docuware debe ser definido y validado con R4 antes del inicio del desarrollo de V2.


7. Reglas de Experiencia Generales
•	Progresividad del wizard: El flujo de onboarding se presenta como un wizard paso a paso con indicador de progreso visible (ej: 'Paso X de N'). La experiencia debe ser simple, guiada y transparente en todo momento.
•	Navegación bidireccional: El usuario puede retroceder al paso anterior usando el botón de flecha izquierda disponible en cada paso (excepto el Paso 1). Al retroceder, los datos ingresados previamente deben preservarse.
•	Completar después: En los pasos donde se habilita esta opción, el sistema guarda el progreso actual y permite al usuario retomar el proceso en una sesión posterior desde el mismo punto.
•	Borrar datos ingresados: En los pasos donde se habilita, el botón 'Borrar datos ingresados' limpia únicamente los campos del paso actual. No afecta datos de pasos anteriores.
•	Feedback en tiempo real: Las validaciones de campos (especialmente contraseña y OTP) deben mostrarse en tiempo real, indicando el estado de cada requisito (cumplido / pendiente) sin necesidad de enviar el formulario.
•	Enmascaramiento de datos sensibles: El correo electrónico del destinatario del OTP debe mostrarse parcialmente enmascarado en la pantalla de verificación (ej: j***@gmail.com).
•	Diseño responsive: La plataforma web cliente debe estar optimizada para navegadores de escritorio y dispositivos móviles. [PENDIENTE: confirmar breakpoints específicos con el equipo de diseño].
•	Trazabilidad de auditoría: Cada acción relevante del usuario durante el onboarding (inicio de sesión, selecciones, cargas de archivos, verificaciones) debe quedar registrada con timestamp y datos del usuario para cumplimiento de auditoría SUDEBAN.


8. Errores Esperados
•	Email ya registrado: El usuario intenta registrarse con un correo electrónico que ya existe en el sistema. Acción: el sistema bloquea el avance, muestra mensaje informativo e indica al usuario que puede iniciar sesión o recuperar su contraseña.
•	Cédula ya registrada: El usuario ingresa un número de cédula que ya existe en el sistema. Acción: el sistema bloquea el avance y notifica al usuario con un mensaje claro.
•	OTP incorrecto: El código de 6 dígitos ingresado no coincide con el enviado. Acción: el sistema muestra error en los campos OTP, informa que el código es incorrecto e invita a reintentar o reenviar.
•	OTP expirado: El código OTP ha superado su tiempo de validez. Acción: el sistema muestra el error, deshabilita el campo de ingreso y activa automáticamente la opción 'Reenviar código'. [PENDIENTE: definir tiempo de expiración del OTP con R4].
•	Contraseña no cumple requisitos: Uno o más requisitos de contraseña no se cumplen al intentar avanzar. Acción: el botón de avance permanece deshabilitado; los requisitos no cumplidos se resaltan visualmente en rojo o con icono de error.
•	Contraseñas no coinciden: El campo 'Confirmar contraseña' no es idéntico al campo 'Contraseña'. Acción: el sistema indica visualmente que las contraseñas no coinciden y deshabilita el avance.
•	Archivo con formato no soportado: El usuario intenta cargar un documento en un formato no aceptado (diferente a SVG, PNG, JPG, GIF). Acción: el sistema rechaza el archivo, muestra mensaje de error indicando los formatos válidos y permite reintento.
•	Archivo que excede dimensiones: El archivo cargado supera el límite de 800×400 px. Acción: el sistema rechaza el archivo y muestra mensaje indicando la restricción.
•	Error en envío de correo OTP: El proveedor de correo no pudo entregar el OTP. Acción: el sistema informa al usuario que hubo un problema con el envío y habilita la opción de reenvío inmediato.
•	Error del motor de pre-análisis: El motor no puede generar la propuesta por ausencia de tabla de parámetros o error de procesamiento. Acción: el sistema no muestra valores incorrectos; gestiona el estado de forma controlada. [PENDIENTE: definir mensaje y comportamiento exacto con R4].
•	Pérdida de sesión durante el flujo: El usuario pierde la sesión por inactividad o cierre del navegador. Acción: al reingresar, si usó 'Completar después', el sistema recupera el progreso guardado; en caso contrario, el sistema informa que se puede retomar desde el inicio.


9. Criterios de Aceptación
•	CA-01: Flujo A completo: Un usuario nuevo puede completar los 4 pasos del Flujo A (selección de tipo de cliente, tipo de persona, datos básicos + OTP y contraseña) y quedar registrado exitosamente en el sistema.
•	CA-02: Verificación OTP funcional: El sistema envía un código OTP de 6 dígitos al correo registrado en máximo [PENDIENTE: tiempo] segundos. El código puede ser verificado correctamente. La opción 'Reenviar código' genera un nuevo OTP válido.
•	CA-03: Validación de contraseña en tiempo real: Los 6 requisitos de contraseña (número, mayúscula, especial, minúscula, longitud 8-32, coincidencia) se validan y muestran en tiempo real. El botón de avance solo se habilita al cumplir todos los requisitos.
•	CA-04: Prevención de duplicados: El sistema impide el registro de un email o cédula que ya existe en la base de datos, mostrando un mensaje de error claro al usuario.
•	CA-05: Flujo B completo: Un usuario registrado puede completar los 5 pasos del Flujo B (perfil, actividad económica, ingresos, documentos y resultado) y recibir una pantalla de pre-análisis con los datos de la oferta preliminar.
•	CA-06: Campos condicionados por condición laboral: Al seleccionar 'Empleado' en Paso 2 del Flujo B, el sistema despliega los campos Empresa, Antigüedad laboral, Tipo de ingreso y Frecuencia de ingreso de forma dinámica. Lo mismo aplica para las otras condiciones con sus campos específicos.
•	CA-07: Carga de documentos obligatorios: El sistema no permite avanzar del Paso 4 si no se han cargado los 3 documentos obligatorios (Documento de identidad, RIF, Certificación de ingresos). Los archivos cargados respetan el formato y las dimensiones definidas.
•	CA-08: Pre-análisis y propuesta preliminar: Después de completar los pasos del Flujo B, el sistema genera y muestra correctamente la pantalla de pre-aprobación con: cuota mensual estimada, plazo, monto pre-aprobado, tasa estimada (%) y total estimado a pagar.
•	CA-09: Funcionalidad 'Completar después': El usuario puede guardar su progreso en cualquier paso habilitado con esta opción y retomar el proceso en una sesión posterior, encontrando todos sus datos previamente ingresados.
•	CA-10: Trazabilidad de auditoría: Todas las acciones relevantes del usuario durante el onboarding (inicio, selecciones de tipo, verificación OTP, cargas de archivos, resultado de pre-análisis, decisión final) quedan registradas en el sistema con timestamp, identificador de usuario y tipo de acción.
•	CA-11: Almacenamiento on-premise: Todos los datos personales, financieros y documentos del cliente se almacenan en la infraestructura on-premise provista por R4, conforme al requisito de SUDEBAN.
•	CA-12: Notificación por correo: El cliente recibe notificaciones por correo electrónico en las etapas clave del proceso (envío de OTP y avances del proceso). El correo es entregado al destinatario correcto.


10. Preguntas Abiertas
•	PO-01 — Tiempo de expiración del OTP: ¿Cuál es el tiempo de validez del código OTP de verificación? ¿Cuántos intentos fallidos se permiten antes de bloquear el proceso? Responsable de respuesta: R4.
•	PO-02 — Opciones de listas desplegables: Se requiere confirmación de los valores completos para: Estado civil, Profesión u ocupación, Antigüedad laboral, Tipo de ingreso principal y Frecuencia de ingreso. Responsable de respuesta: R4.
•	PO-03 — Catálogos geográficos: ¿R4 suministrará el catálogo oficial de Estados y Ciudades de Venezuela para el campo de dirección? Responsable de respuesta: R4.
•	PO-04 — Pasos adicionales del Paso 3 (Flujo B): La Epic Description menciona pasos adicionales en el Flujo B: gastos, compromisos financieros, monto solicitado ($100–$10.000), plazo (30/60/90 días) y propósito del crédito. Estos no están visibles en las pantallas de referencia proporcionadas. ¿Se incluyen en V1? Responsable de respuesta: R4 / Producto.
•	PO-05 — Términos y Condiciones: ¿El Paso 5 del Flujo B incluye un paso de aceptación formal de Términos y Condiciones antes de mostrar el resultado del pre-análisis? ¿Cuál es el contenido y el mecanismo de aceptación? Responsable de respuesta: R4 / Legal.
•	PO-06 — Campos adicionales para Persona Jurídica: El flujo mostrado en las pantallas de referencia corresponde principalmente a Persona Natural. ¿Qué campos adicionales o diferentes debe mostrar el formulario para una Persona Jurídica? Responsable de respuesta: R4.
•	PO-07 — Campos adicionales por condición laboral: ¿Qué campos específicos se despliegan cuando la condición laboral seleccionada es Independiente, Comerciante, Jubilado u Otro? Responsable de respuesta: R4.
•	PO-08 — Tabla de parámetros del motor de pre-análisis: R4 debe suministrar la tabla de parámetros financieros utilizada para calcular el pre-análisis (monto máximo, tasas, plazos según perfil). Sin este insumo no es posible configurar ni probar el motor de pre-análisis. Responsable de respuesta: R4.
•	PO-09 — Proveedor de correo / SMS: ¿Cuál es el proveedor de correo electrónico o mensajería que R4 proveerá para el envío del OTP y notificaciones? ¿Existen credenciales o APIs disponibles? Responsable de respuesta: R4 / IT.
•	PO-10 — Edad mínima del solicitante: ¿Existe una restricción de edad mínima para ser solicitante de crédito en R4? Esto impacta la validación del campo 'Fecha de nacimiento'. Responsable de respuesta: R4 / Legal.
•	PO-11 — Endpoint API de Procert para OTP: ¿R4 tiene acceso activo a la API de Procert? ¿Cuál es el endpoint y la especificación para la generación y validación de OTP en V1? Responsable de respuesta: R4 / Procert.
•	PO-12 — Comportamiento del flujo para 'Cliente fijo': ¿El flujo de un 'cliente fijo' que ya tiene registro en el sistema difiere del flujo de un 'cliente nuevo'? ¿Se pre-pueblan datos adicionales desde el Core Bancario COBIS para clientes fijos en V1? Responsable de respuesta: R4.
•	PO-13 — Información de seguridad y políticas de contraseña: El documento Pre-Ventas indica que R4 tiene pendiente enviar información de seguridad. ¿Existen políticas adicionales de contraseña (número máximo de intentos, bloqueo de cuenta, período de expiración) requeridas por SUDEBAN? Responsable de respuesta: R4 / Seguridad.


Documento generado por Avila Tek — Preventas | R4 Créditos | Marzo 2026
