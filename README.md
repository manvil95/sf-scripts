# :rocket: sf-scripts

## :hammer_and_wrench: validate-deployment

>[!NOTE]
> Este script de Bash, denominado validate_deployment.sh, está diseñado para facilitar la validación de despliegues en un entorno de Salesforce. 
> A través de la ejecución de un comando, el script verifica la validez de un manifiesto y ejecuta un conjunto de pruebas Apex definidas en un archivo de test suite.

### :gear: Ejecución del Script

Para ejecutar el script, ingrese el siguiente comando en una consola Bash:

```bash
./scripts/bash/validate_deployment.sh <nombre_del_manifiesto> <organizacion_objetivo>
```

### :round_pushpin: Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| **<nombre_del_manifiesto>**| El nombre del archivo XML del manifiesto, ubicado en el directorio ./manifest/.|
| **<organizacion_objetivo>**| La organización de Salesforce contra la cual se realizará la validación del despliegue. |

### :computer: Ejemplos de Uso

Para validar un despliegue utilizando el manifiesto package.xml contra la organización myOrg:

```bash
./scripts/bash/validate_deployment.sh package.xml myOrg
```

### :mag: Funcionamiento del Script

1. **Comprobación de Argumentos**

    El script inicia comprobando que se hayan proporcionado los dos argumentos necesarios. Si no se recibe la cantidad correcta de argumentos, se muestra un mensaje de error y el script se detiene.

2. **Configuración y Verificación de Archivos**

    - Utiliza la ruta ./manifest/ para ubicar el archivo de manifiesto.
    - Verifica la existencia del archivo especificado por el usuario. Si el archivo no existe, se emite un mensaje de error.

3. **Lectura y Procesamiento del Archivo Test Suite**

    El script procede a leer el testSuite-meta.xml para extraer los nombres de las clases de pruebas Apex. Esta información se compila en una lista que se utiliza para el comando de validación.

4. **Construcción y Ejecución del Comando**

    - Genera un comando utilizando los parámetros proporcionados y la lista de pruebas Apex generada.
    - Ejecuta el comando utilizando eval.

5. :warning: **Errores Comunes**

    - Falta de argumentos: Asegúrese de proporcionar los dos argumentos necesarios al ejecutar el script.
    - Archivo de manifiesto inexistente: Confirme que el archivo existe en el directorio esperado.

### :pushpin: Notas

- Este script está diseñado para validaciones en entornos de desarrollo, no en entornos productivos.
- Los tests que ejecuta son los especificados en el archivo testSuite-meta.xml.
- Es recomendado almacenar el script en la carpeta ./scripts/bash/.
- Ejecutar el script siempre desde una consola Bash.

