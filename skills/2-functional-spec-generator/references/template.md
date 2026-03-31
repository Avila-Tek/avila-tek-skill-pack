# ── TEMPLATE v2 — calibrado contra spec real ──
# Spec Funcional: [Nombre de la Épica]

| Proyecto | Responsable | Editores | Estado |
|----------|-------------|----------|--------|
|          |             |          | Draft / En Revisión / Aprobado |

---

## 1. Resumen ejecutivo y objetivo

- **Objetivo de la épica:** [Describir el propósito principal y qué problema resuelve para el usuario].
- **Dependencias críticas:** [Listar sistemas, APIs o módulos previos necesarios para que este desarrollo funcione].
- **Métricas de éxito (KPIs):** [Definir indicadores cuantificables de negocio o producto que se verán impactados, ej: % de conversión, reducción de errores, tiempo de proceso].

---

## 2. Alcance (In & Out)

- **Incluido en la épica:** [Listado de funcionalidades]
- **Fuera de alcance de la épica:** [Listado de exclusiones explícitas para evitar ambigüedades].

---

## 3. Matriz de actores y roles

- **Usuario final:** [Definir quién usa la funcionalidad, ej: Cliente, Admin, Soporte].
- **Sistemas internos:** [Módulos propios que intervienen, ej: Base de datos, Core de pagos].
- **Servicios de terceros:** [APIs o proveedores externos, ej: Google Auth, Stripe, Maps].

---

## 4. Reglas de negocio aplicables a la épica

Reglas globales que rigen toda la funcionalidad, independientemente del flujo.

- [Regla 1: Ej -> Definición de identidad o llave maestra].
- [Regla 2: Ej -> Requisitos obligatorios de seguridad o cumplimiento].
- [Regla 3: Ej -> Restricciones de acceso o permisos globales].

---

## 5. Definición de Flujos (Step-by-Step)

### Flujo A: [Nombre del Flujo]

- **Entrada:** [Punto de inicio y acción que dispara el flujo].
- **Proceso del Sistema:** [Pasos, validaciones automáticas, lógica de fondo y comunicaciones enviadas].
- **Bloqueos Funcionales:** [Pasos obligatorios que impiden avanzar si no se completan].
- **Integración:** [Momento en que se consulta o envía información a servicios externos].
- **Resultado final:** [Estado final del usuario y del sistema al terminar con éxito].

**Detalles del Flujo A:**

- **Reglas funcionales:** [Lógica específica que aplica solo a este camino].
- **Casos borde:** [Escenarios atípicos: datos duplicados, errores de red, registros existentes].
- **Datos y validaciones del flujo:** [Campos mínimos, formatos requeridos, etc].
- **Estados funcionales:** [Ciclo de vida de los objetos, ej: Pendiente -> Activo].

---

## 6. Integraciones externas

### [Nombre del Servicio/API]

- **Se usa para:** [Mencionar en qué flujos interviene y con qué propósito].
- **Datos esperados:** [Listado de parámetros de entrada y salida necesarios].

---

## 7. Reglas de experiencia generales

- [Regla 1: Ej -> Lineamientos de mensajes: cortos, accionables y sin tecnicismos].
- [Regla 2: Ej -> Lógica de navegación: redirecciones automáticas ante pasos incompletos].
- [Regla 3: Ej -> Tratamiento visual de errores y estados de carga].

---

## 8. Errores esperados

- [Error A]: [Causa y mensaje/acción propuesta].
- [Error B]: [Causa y mensaje/acción propuesta].

---

## 9. Criterios de aceptación

- [Criterio 1: Condición sine qua non para el paso a producción].
- [Criterio 2: Comportamiento esperado en pruebas de estrés o seguridad].
- [Criterio 3: Validación de flujos críticos de extremo a extremo].

---

## 10. Preguntas abiertas

- [Duda 1: Temas técnicos o de negocio pendientes de definición].
- [Duda 2: Limitaciones de terceros por confirmar].
