# 🚀 Trabajo Práctico: Análisis Técnico de Stored Procedures - Sample Vault

Este repositorio contiene un análisis de sistemas enfocado en la implementación de **Stored Procedures (Procedimientos Almacenados)** en el proyecto *Sample Vault*. Se evalúa de manera crítica su integración con un backend en Node.js, la seguridad de las transacciones y el impacto en la escalabilidad y consistencia de los datos.

---

## ⚙️ Entorno de Ejecución Local

Para realizar las auditorías y verificar el comportamiento del sistema, se replicó el entorno de desarrollo de forma local siguiendo este flujo de despliegue:

1. **Instalación de Dependencias**: Inicialización de entornos mediante la consola de Node dentro de la carpeta `backend` (`npm install`).
2. **Configuración de Variables de Entorno**: Creación del archivo `.env` al mismo nivel que `package.json` para desacoplar las credenciales del código (`PORT`, `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`, `JWT_SECRET`, `NODE_ENV`).
3. **Levantamiento del Motor DB**: Uso de **UniserverZ** para inicializar los servicios locales de MariaDB/MySQL. Importación estructurada del script `init.sql` para crear la base de datos, tablas, relaciones jerárquicas y rutinas.
4. **Automatización de Procesos**: Creación y uso de un archivo de procesamiento por lotes (`.bat`) para automatizar el arranque de `npm` y disparar la interfaz del navegador.
5. **Validación de Rutas**: Ejecución y paso exitoso de la suite de pruebas del laboratorio frontend integradas con la API.

---

## 🔍 Análisis de Arquitectura y Datos (Enfoque de Sistemas)

Como analistas, nuestra función es auditar el comportamiento del software más allá del "Happy Path" (cuando todo funciona bien). Evaluando los componentes técnicos del proyecto tal cual están implementados, se identificaron aciertos lógicos de diseño y vulnerabilidades estructurales severas.

### 🛡️ 1. Capa de Seguridad y Base de Datos (`init.sql`)
* **Acierto - Principio de Menor Privilegio**: Excelente decisión técnica al aislar al usuario `samplevaultest` otorgándole de forma exclusiva permisos de `SELECT` y `EXECUTE`. Si la API sufriera un ataque de inyección o vulneración de código, el atacante no posee privilegios para mutar datos de forma directa (`INSERT`, `UPDATE`, `DELETE`) ni para destruir la estructura (`DROP`).
* **Acierto - Integridad Referencial**: La declaración de restricciones `ON DELETE CASCADE` en las tablas intermedias (`users_roles`) y dependientes (`samples`) delega de manera eficiente la consistencia relacional directamente al motor DB, ahorrando lógica de limpieza manual en el backend.
* **Falla Crítica - Transaccionalidad**: El procedimiento `sp_create_user` realiza operaciones de escritura secuenciales sobre dos tablas diferentes (`users` y `users_roles`). Al carecer de bloques de control transaccional (`START TRANSACTION`, `COMMIT`, `ROLLBACK`), si el segundo `INSERT` falla (por ejemplo, si se le pasa un nombre de rol inexistente), la primera inserción queda persistida. **Esto rompe la propiedad de atomicidad (ACID)** y genera datos corruptos/usuarios huérfanos sin rol asignado en el sistema.

### 💻 2. Capa de Repositorios (Node.js + Driver `mysql2`)
* **Acierto - Consultas Parametrizadas**: El uso sistemático de `pool.execute('CALL sp(?, ?)')` garantiza que las variables de entrada sean sanitizadas por el driver, bloqueando vectores comunes de inyección SQL.
* **Falla Crítica - Fragilidad ante Fallos**: Los repositorios (`userRepo.js` y `sampleRepo.js`) asumen un flujo ciego de éxito al desestructurar las respuestas en memoria (ej: `return rows[0][0].insertId;`). Al invocar un procedimiento, `mysql2` devuelve una estructura compleja de sub-arreglos y metadatos. Si el SP falla internamente o no halla registros, el índice del Data Set será `undefined`. Intentar leer una propiedad de un objeto indefinido dispara una excepción `TypeError` que, de no ser interceptada por un middleware global, tumbará por completo el hilo de ejecución del servidor Express (Crash).

### 🧪 3. Laboratorio de Pruebas (`frontend/js/tests/`)
* El entorno incluye una interfaz gráfica para simular eventos contra el backend y renderizar las respuestas de la API en una consola virtualizada.
* **Naturaleza de los Tests**: Están diseñados intencionalmente como simulaciones de caja negra. Algunos tests deben dar luz verde (éxito) y otros deben fallar con gracia ante contraseñas inválidas o usuarios no autorizados, validando la lógica perimetral del servidor.
* **Punto de Mejora**: Se detectaron errores redundantes de duplicación de código ("copy-paste") en el archivo `authTests.js`. El test rotulado para usuarios incorrectos envía exactamente el mismo JSON de payload (usuario "pepe" y clave "123") que el test de contraseña incorrecta. Esto genera falsos positivos en el reporte de cobertura de pruebas, ya que no se está evaluando el escenario real descrito en el botón.

---

## 📈 Conclusiones y Propuestas de Escalabilidad

Para que la arquitectura de este proyecto sea considerada robusta, segura y apta para un entorno de producción masivo, se deben implementar las siguientes correcciones de ingeniería:

1. **Atomicidad en Base de Datos**: Reestructurar los Stored Procedures mutables utilizando cláusulas `DECLARE EXIT HANDLER FOR SQLEXCEPTION` asociadas a transacciones explícitas para garantizar que el sistema vuelva a un estado consistente si un paso intermedio falla.
2. **Programación Defensiva en Backend**: Sustituir el acceso directo a arreglos anidados en los repositorios por operaciones validadas o encadenamiento opcional (ej: `rows[0]?.[0]?.insertId || null`) para inmunizar la aplicación contra respuestas inesperadas del motor DB.
3. **Refactorización del Laboratorio**: Corregir los objetos de petición (`payloads`) en la suite de pruebas del frontend para que mapeen con veracidad los casos borde descritos en la interfaz gráfica.
