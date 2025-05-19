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

5. **Errores Comunes**

    - Falta de argumentos: Asegúrese de proporcionar los dos argumentos necesarios al ejecutar el script.
    - Archivo de manifiesto inexistente: Confirme que el archivo existe en el directorio esperado.

### :pushpin: Notas

- Este script está diseñado para validaciones en entornos de desarrollo, no en entornos productivos.
- Los tests que ejecuta son los especificados en el archivo testSuite-meta.xml.
- Es recomendado almacenar el script en la carpeta ./scripts/bash/.
- Ejecutar el script siempre desde una consola Bash.

## :hammer_and_wrench: findMetadataErrors-v1.sh

> [!NOTE]
> Este script se encarga de verificar la existencia de ciertos metadatos dentro de una organización de Salesforce a partir de un archivo XML proporcionado de una aplicación personalizada o conjunto de permisos.

### :gear: Ejecución del Script

Para ejecutar el script, ingrese el siguiente comando en una consola Bash:

```bash
./scripts/bash/findMetadataErrors-v1.sh --metadata-name <metadataName> --target-org <orgName> --metadata-type <metadataType>
./scripts/bash/findMetadataErrors-v1.sh -n <metadataName> -o <orgName> -t <metadataType> --queries-result --export-json
```

### :round_pushpin: Parámetros

| Parámetro | Descripción |
|-----------|-------------|
| **-n, --metadata-name** <value> | Nombre de la metadata a verificar (requerido) |
| **-o, --target-org** <value> | La organización de Salesforce contra la cual se realizará la validación del despliegue. |
| **-t, --metadata-type** <value> | Tipo de metadato, puede ser 'application' (app) o 'permissionset' (ps) (requerido). |
| **--export-json** | Exporta metadata extraída del archivo XML a formato JSON |
| **--queries-result** | Exporta resultados de las consultas a archivo JSON. |
| **--help** | Muestra la ayuda del script. |

### :mag: Funcionamiento del Script

1. **Verificación de Parámetros**:
    
    Asegura que se han proporcionado todos los parámetros necesarios, incluyendo la ruta del archivo XML, alias de la organización y tipo de metadato.
   
2. **Verificación e Instalación de jq**:

    Asegura que la herramienta jq está instalada para el procesamiento JSON. Si no está instalada, guía para instalarla con Chocolatey.
   
3. **Comprobación de la Existencia del Archivo**:
    
    Verifica si el archivo XML especificado existe. Si no, detiene la ejecución con un error.
   
4. **Extracción de Metadatos del XML**:
    
    Procesa el archivo XML para extraer los metadatos definidos y los organiza para la consulta.
   
5. **Consultas a Salesforce**:
    
    Realiza consultas agrupadas para cada tipo de metadato en la organización de Salesforce dada.
    
6. **Presentación de Resultados**:

    Imprime los resultados indicando si los metadatos especificados se encontraron o no en la organización.

### :pushpin: Notas

- El script eliminará automáticamente los archivos temporales a menos que se especifique lo contrario con las banderas --export-json o --queries-result. 
- Al final del proceso, se imprimen los resultados indicando si todos los metadatos esperados se encuentran presentes.
