#!/bin/bash

# Este script verifica la existencia de ciertos metadatos en una organización de Salesforce a partir de un archivo XML de una (Custom) Application.

# Funcionalidades principales:
# 1. Verifica si se han proporcionado los parámetros necesarios (ruta del archivo y alias de la organización).
# 2. Verifica e instala la herramienta 'jq' si no está instalada.
# 3. Verifica si el archivo especificado existe.
# 4. Procesa el archivo XML para extraer los metadatos especificados.
# 5. Realiza consultas agrupadas a la organización de Salesforce para verificar la existencia de los metadatos.
# 6. Imprime los resultados de las consultas, indicando si los metadatos se encontraron o no en la organización.

# Comando para su ejecución
# ./scripts/bash/findMetadataErrors-v5.sh --metadata-name metadataName --target-org orgName --metadata-type application
# ./scripts/bash/findMetadataErrors-v5.sh -n metadataName -o orgName -t app

#-------------------------------------------------------------------------------------------------
# F U N C I O N E S  P A R A  I M P R I M I R  P O R  P A N T A L L A
#-------------------------------------------------------------------------------------------------

echo_yellow() {
    local text="$1"
    echo -e "\033[33m${text}\033[0m"  # \033[33m es el código ANSI para amarillo
}

echo_red() {
    local text="$1"
    echo -e "\033[31m${text}\033[0m"  # \033[31m es el código ANSI para rojo
}

printf_red() {
    local text="$1"
    printf "\033[31m${text}\033[0m "
}

echo_red_bold() {
    local text="$1"
    echo -e "\033[1;31m${text}\033[0m"  # \033[1;31m es el código ANSI para rojo y negrita
}

echo_green() {
    local text="$1"
    echo -e "\033[32m${text}\033[0m"  # \033[32m es el código ANSI para verde
}

printf_green() {
    local text="$1"
    printf "\033[32m${text}\033[0m"  # \033[32m es el código ANSI para verde
}

echo_blue() {
    local text="$1"
    echo -e "\033[34m${text}\033[0m"  # \033[34m es el código ANSI para azul
}

printf_blue() {
    local text="$1"
    printf "\033[34m${text}\033[0m"  # \033[34m es el código ANSI para azul
}

echo_blue_bold() {
    local text="$1"
    echo -e "\033[1;34m${text}\033[0m"  # \033[1;34m para negrita y azul,
}

#-------------------------------------------------------------------------------------------------
# F U N C I O N E S  S E C U N D A R I A S
#-------------------------------------------------------------------------------------------------

# Función para verificar e instalar jq si no está instalado
install_jq() {
    # Verifica si el comando 'jq' no está disponible
    if ! command -v jq &> /dev/null; then
        # Muestra un mensaje indicando que jq no está instalado
        echo "jq no está instalado. Instalando jq..."
        
        # Verifica si el comando 'choco' (Chocolatey) está disponible
        if command -v choco &> /dev/null; then
            # Instala jq usando Chocolatey
            choco install jq -y
        else
            # Muestra un mensaje indicando que Chocolatey no está instalado y proporciona un enlace para su instalación
            echo "Chocolatey no está instalado. Por favor, instala Chocolatey primero: https://chocolatey.org/install"
            # Termina la ejecución del script con un código de error
            exit 1
        fi
        
        # Verifica si la instalación de jq fue exitosa
        if ! command -v jq &> /dev/null; then
            # Muestra un mensaje indicando que la instalación de jq falló
            echo "La instalación de jq falló. Por favor, instálalo manualmente."
            # Termina la ejecución del script con un código de error
            exit 1
        fi
    fi
}

# Función para verificar si el archivo existe
check_file_exists() {
    echo_yellow "\nVerificando existencia del archivo.xml..."
    # Verifica si el archivo especificado no existe
    if [ ! -f "$1" ]; then
        # Muestra un mensaje indicando que el archivo no existe
        echo_red_bold "\nEl archivo.xml $1 no existe."
        # Termina la ejecución del script con un código de error
        exit 1
    fi
    echo_green "Archivo.xml verificado."
}

# Función para procesar una línea del archivo
process_line() {
    local line=$1
    local cmt_pattern="customMetadataType"
    # Itera sobre los patrones definidos
    for pattern in "${patterns[@]}"; do
        # Verifica si la línea coincide con el patrón actual
        # if [[ $line =~ ^[[:space:]]*\<${pattern}\>(.*)\<\/${pattern}\> ]]; then
        if [[ $line =~ ^[[:space:]]*\<${pattern}\>(.*)\<\/${pattern}\> ]] && [[ "$pattern" != "name" ]] || 
        { [[ "$pattern" == "name" ]] && [[ $line =~ ^[[:space:]]*\<${pattern}\>(.*__mdt.*)\<\/${pattern}\> ]]; }; then
            local content=${BASH_REMATCH[1]}
            # Si el contenido es 'Admin', lo cambia a 'System Administrator'
            if [[ $content == 'Admin' ]]; then
                content="System Administrator"
            fi
            
            local content_pattern="$content+$pattern"
            # Si el contenido no ha sido procesado antes, lo agrega a la metadata
            if [[ -z "${processed_values[$content_pattern]}" ]]; then
                # Almacenar el contenido como un valor en un array en lugar de un string

                if [[ $pattern == "name" ]]; then
                    metadata[$cmt_pattern]+="$content|"
                else
                    metadata[$pattern]+="$content|"
                fi

                processed_values[$content_pattern]=1
            fi
        fi
    done
}

# Nueva función para guardar metadata en un archivo JSON como arrays
save_metadata_to_json() {
    echo_yellow "\nGenerando archivo .json con la metadata extraida."

    local json_output="{"
    for key in "${!metadata[@]}"; do
        # Convertir el string a un array separando por el carácter '|' y luego construir el JSON
        IFS='|' read -r -a values_array <<< "${metadata[$key]}"
        
        # Ordenar los valores alfabéticamente
        IFS=$'\n' sorted_values=($(sort <<<"${values_array[*]}"))
        unset IFS
        
        json_output+="\"$key\": ["
        # Crear la representación del array en formato JSON
        for value in "${sorted_values[@]}"; do
            json_output+="\"$value\","
        done
        # Eliminar la última coma y cerrar el array
        json_output=${json_output%,}
        json_output+="],"
    done
    # Eliminar la última coma y cerrar el objeto JSON
    json_output=${json_output%,}
    json_output+="}"

    # Guardar el JSON sin formato en un archivo temporal
    echo "$json_output" > temp.json
    # Utilizar jq para formatear el JSON y guardarlo finalmente con tabulaciones
    jq '.' temp.json > extractedMetadata.json
    rm temp.json  # Eliminar el archivo temporal

    echo_green "Metadata guardada en extractedMetadata.json"
}

# Función para realizar la consulta agrupada y verificar los resultados
query_and_verify_results() {
    local type=$1
    local target_org=$2
    local query
    local use_tooling_api=""
    local contents_str

    # Extraer la cadena de contenidos desde el JSON usando jq
    contents_str=$(jq -r --arg type "$type" '.[$type][]' extractedMetadata.json | sed "s/^/'/; s/$/'/" | tr '\n' ',')
    contents_str=${contents_str%,}  # Elimina la última coma
    # Define la consulta según el tipo de metadato
    case $type in
        application)
            query="SELECT DeveloperName FROM CustomApplication WHERE DeveloperName IN ($contents_str)"
            use_tooling_api="--use-tooling-api"
            ;;
        content|utilityBar)
            query="SELECT DeveloperName FROM FlexiPage WHERE DeveloperName IN ($contents_str)"
            use_tooling_api="--use-tooling-api"
            ;;
        profile)
            query="SELECT Name FROM Profile WHERE Name IN ($contents_str)"
            ;;
        apexClass)
            query="SELECT Name FROM ApexClass WHERE Name IN ($contents_str)"
            ;;
        object|customMetadataType)
            contents_str="${contents_str//__c/}" # Eliminamos las terminaciones custom "__c"
            contents_str="${contents_str//__mdt/}" # Eliminamos las terminaciones custom "__c"
            query="SELECT DeveloperName FROM EntityDefinition WHERE DeveloperName IN ($contents_str)"
            ;;
        tabs|tab)
            query="SELECT Name FROM TabDefinition WHERE Name IN ($contents_str)"
            use_tooling_api="--use-tooling-api"
            ;;
        logo)
            query="SELECT DeveloperName FROM ContentAsset WHERE DeveloperName IN ($contents_str)"
            ;;
        recordType|field)
            # Crea un mapa para agrupar los DeveloperNames por objeto
            declare -A object_map
            IFS=',' read -ra contents_array <<< "$contents_str"  # Convierte el contents_str a un array

            local metadata_count=${#contents_array[@]}
            local cont=1
            echo ""

            for content in "${contents_array[@]}"; do
                echo -ne "Procesando $type... $cont de $metadata_count \r"
                local object=$(echo "$content" | sed "s/^'//; s/\.[^.]*$//" | cut -d'.' -f1) # Extraer el object
                local developerName=$(echo "$content" | cut -d'.' -f2 | sed "s/'$//") # Extraer el developerName
                if [[ -n "$object" && -n "$developerName" ]]; then
                    if [[ "$type" == "field" &&  "$developerName" == *__c ]]; then
                        developerName="${developerName%__c}"
                    fi
                    object_map[$object]+="'$developerName',"
                fi
                cont=$((cont + 1))
            done

            # Realiza la consulta para cada objeto
            for object in "${!object_map[@]}"; do
                local developerNames_str=${object_map[$object]%,}  # Elimina la última coma
                
                if [[ "$type" == "recordType" ]]; then
                    query="SELECT DeveloperName FROM RecordType WHERE SobjectType = '$object' AND DeveloperName IN ($developerNames_str)"
                fi
                
                if [[ "$type" == "field" ]]; then
                    if [[ "$object" == *__c ]]; then
                        object="${object%__c}"
                    fi
                    query="SELECT DeveloperName FROM CustomField WHERE EntityDefinition.DeveloperName = '$object' AND DeveloperName IN ($developerNames_str)"
                    use_tooling_api="--use-tooling-api"
                fi
                
                check_query_results "$query" "$target_org" "$type" "$object" "$developerNames_str"
            done
            return
            ;;
    esac
    
    # Verifica los resultados de la consulta
    check_query_results "$query" "$target_org" "$type"
}

# Función para verificar los resultados de la consulta
check_query_results() {
    local query=$1
    local target_org=$2
    local type=$3
    local object=$4
    local developerNames_str=$5

    # Muestra la consulta que se va a ejecutar
    echo_yellow "\n\n-- Query for ${type^^} $object --"
    # echo -e "----------------------------------------"
    echo_blue "$query \n$use_tooling_api"

    export NODE_NO_WARNINGS=1

    # Ejecuta la consulta y almacena el resultado
    if [[ $keep_query_results == true ]]; then
        result=$(sf data query --query "$query" $use_tooling_api --target-org "$target_org" --json >> result.json)
    fi
    
    result=$(sf data query --query "$query" $use_tooling_api --target-org "$target_org" --json)

    # Restaurar las salidas
    unset NODE_NO_WARNINGS

    # Usa jq para obtener el totalSize
    local totalSize=$(echo "$result" | jq '.result.totalSize')

    local contents_array
    IFS='|' read -r -a contents_array <<< "${metadata[$type]}"
    local metadata_count=${#contents_array[@]}

    # Ajusta el conteo de metadatos para recordType
    if [ "$type" == "recordType" ]; then
        local object_array=(${object_map[$object]})
        metadata_count=$(echo "$developerNames_str" | tr -cd ',' | wc -c)
        metadata_count=$((metadata_count + 1))  # El número de record types es el número de comas más uno
    fi
    
    if [ "$type" == "field" ]; then
        local object_array=(${object_map[$object]})
        metadata_count=$(echo "$developerNames_str" | tr -cd ',' | wc -c)
        metadata_count=$((metadata_count + 1))  # El número de record types es el número de comas más uno
    fi

    # Muestra los resultados de la búsqueda
    echo_red_bold "\n\t$type ${object^^}"
    # echo_red_bold "\t----------------------------------------"
    echo -e "\t- Total Count XML -> $metadata_count"
    echo -e "\t- Total Count ORG -> $totalSize"

    # Verifica si los resultados coinciden
    if [ "$totalSize" -ne "$metadata_count" ]; then
        # Usa jq para obtener los DeveloperNames encontrados
        local found_developername=($(echo "$result" | jq -r '.result.records[].DeveloperName'))
        local found_name=($(echo "$result" | jq -r '.result.records[].Name'))

        # Verifica cada contenido
        for content in "${contents_array[@]}"; do
            if [ "$type" == "recordType" ]; then
                local obj=$(echo "$content" | cut -d'.' -f1)
                local devName=$(echo "$content" | cut -d'.' -f2)

                if [[ "$obj" == "$object" && ! " ${found_developername[*]} " =~ " ${devName} " ]]; then
                    results+=("$type $content NOT FOUND")
                else
                    results+=("$type $content FOUND")
                fi
            elif [ "$type" == "field" ]; then
                local obj=$(echo "$content" | cut -d'.' -f1)
                local devName=$(echo "$content" | cut -d'.' -f2)

                if [[ "$obj" == "$object" && ! " ${found_developername[*]} " =~ " ${devName} " ]]; then
                    results+=("$type $content NOT FOUND")
                else
                    results+=("$type $content FOUND")
                fi
            elif [ "$type" == "tabs" ] || [ "$type" == "tab" ] || [ "$type" == "profile" ] || [ "$type" == "apexClass" ] ; then
                if [[ ! " ${found_name[*]} " =~ " ${content} " ]]; then
                    results+=("$type $content NOT FOUND")
                else
                    results+=("$type $content FOUND")
                fi
            elif [ "$type" == "object" ] || [ "$type" == "customMetadataType" ]; then
                content="${content//__c/}"
                content="${content//__mdt/}"
                if [[ ! " ${found_developername[*]} " =~ " ${content} " ]]; then
                    results+=("$type $content NOT FOUND")
                else
                    results+=("$type $content FOUND")
                fi
            else
                if [[ ! " ${found_developername[*]} " =~ " ${content} " ]]; then
                    results+=("$type $content NOT FOUND")
                else
                    results+=("$type $content FOUND")
                fi
            fi
        done
    else
        for content in "${contents_array[@]}"; do
            results+=("$type $content FOUND")
        done
    fi
}

#-------------------------------------------------------------------------------------------------
# F U N C I O N E S  P R I N C I P A L E S
#-------------------------------------------------------------------------------------------------

# Función para mostrar la ayuda
show_help() {
    echo_blue_bold "\n\nDESCRIPCIÓN"
    echo -e "Este script busca metadata en el archivo .xml pasado por parámetro. \nRealiza queries en la organización señalada y compara los resultados. \nFinalmente señala aquellos resultados que no están en la organización."
    
    echo_blue_bold "\n\nUSO"
    printf_green "  $"
    printf_blue " $0"
    printf " [-n <value>] [-o <value>] [-t <value>] [--queries-result] [--export-json]\n"
    
    echo_blue_bold "\nFLAGS"
    printf_green "  -n, --metadata-name <value>"
    printf_red "\t(required)"
    printf "Nombre de la metadata a verificar.\n\n"

    printf_green "  -o, --target-org <value>"
    printf_red "\t(required)"
    printf "Alias de la organización de destino.\n\n"
    
    printf_green "  -t, --metadata-type <value>"
    printf_red "\t(required)"
    printf "Tipo de metadato a verificar: 'application' (app) o 'permissionset' (ps).\n"

    echo_blue_bold "\nGLOBAL FLAGS:"
    printf_green "  --export-json"
    printf "\t\tExportar metadata extraída del archivo .xml a formato json.\n\n"
    printf_green "  --queries-result"
    printf "\tExportar resultados de queries a archivo json.\n\n"
    printf_green "  --help"
    printf "\t\tMuestra este mensaje de ayuda.\n"

    echo_blue_bold "\nEJEMPLOS:"
    printf "\nEste comando verifica los metadatos denominados 'usersMetadata' en la organización 'salesOrg' y confirma su tipo como 'permissionset'.\n"
    printf_green "  $"
    printf_blue " $0"
    printf " --metadata-name usersMetadata --target-org salesOrg --metadata-type permissionset\n"

    # Ejemplo 2
    printf "\nAquí se está buscando la metadata 'reportsMetadata' en la organización 'marketingOrg' y se especifica que el tipo es 'application'.\n"
    printf_green "  $"
    printf_blue " $0"
    printf " -n reportsMetadata -o marketingOrg -t app\n"

    # Ejemplo 3
    printf "\nEste comando no solo verifica la metadata 'customerData' en la organización 'supportOrg' como 'application', sino que también exporta la metadata extraída a un archivo JSON.\n"
    printf_green "  $"
    printf_blue " $0"
    printf " --metadata-name customerData --target-org supportOrg --metadata-type application --export-json\n"

    # Ejemplo 4
    printf "\nEn este caso, se busca 'salesReports' en 'salesOrg' con el tipo 'permissionset', y además se exportan los resultados de las consultas a un archivo JSON.\n"
    printf_green "  $"
    printf_blue " $0"
    printf " -n salesReports -o salesOrg -t permissionset --queries-result\n"

    # Ejemplo 5
    printf "\nEste comando realiza la verificación de 'productInfo' en 'devOrg' como 'application' y exporta tanto la metadata extraída como los resultados de las consultas a archivos JSON.\n"
    printf_green "  $"
    printf_blue " $0"
    printf " --metadata-name productInfo --target-org devOrg --metadata-type application --export-json --queries-result\n"
}

# Función para verificar si se han proporcionado los parámetros necesarios
check_parameters() {
    echo_yellow "\nComprobando parámetros de entrada."
    # Verifica si los parámetros $1, $2 y $3 están vacíos
    if [ -z "$metadata_name" ] || [ -z "$target_org" ] || [ -z "$metadata_type" ]; then
        # Muestra un mensaje de error y el uso correcto del script
        echo_red_bold "Por favor, proporciona el nombre de la metadata con --metadata-name o -n, el alias de la organización de destino con --target-org o -o, y el tipo de metadato con --metadata-type o -t como parámetros."
        
        show_help
        # echo "Uso: $0 --metadata-name <nombre_de_la_metadata> --target-org <alias_de_la_org> --metadata-type <tipo_metadato>"
        # echo "Uso: $0 -n <nombre_de_la_metadata> -o <alias_de_la_org> -t <tipo_metadato>"
        # Termina la ejecución del script con un código de error
        exit 1
    fi
    echo_green "Parámetros de entrada comprobados."
}

# Función para procesar los argumentos
process_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --metadata-name|-n)
                metadata_name="$2"
                shift 2
                ;;
            --target-org|-o)
                target_org="$2"
                shift 2
                ;;
            --metadata-type|-t)
                metadata_type="$2"
                shift 2
                ;;
            --export-json)
                keep_metadata_json=true
                shift
                ;;
            --queries-result)
                keep_query_results=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done
}

set_metadata_type() {
    case "$metadata_type" in
        application|app)
            file_path="unpackaged/main/default/applications/$metadata_name.app-meta.xml"
            patterns=("content" "utilityBar" "profile" "tabs" "logo" "recordType")
            ;;
        permissionset|ps)
            file_path="unpackaged/main/default/permissionsets/$metadata_name.permissionset-meta.xml"
            patterns=("application" "apexClass" "field" "object" "recordType" "tab" "name" "customMetadataType")
            ;;
        *)
            echo_red_bold "Tipo de metadato desconocido. Debe ser 'application' o 'permissionset'."
            exit 1
            ;;
    esac
    echo_blue "\nFile path: $file_path"
}

extract_metadata() {
    check_file_exists "$file_path"
    echo_yellow "\nExtrayendo metadata del archivo xml..."
    while IFS= read -r line; do
        process_line "$line"
    done < "$file_path"
    echo_green "Metadata extraida."
}

perform_queries() {
    echo_yellow "\nRealizando queries y comprobacion..."
    for pattern in "${patterns[@]}"; do
        if [ -n "${metadata[$pattern]}" ]; then
            query_and_verify_results "$pattern" "$target_org"
        fi
    done
    echo_green "\nProceso de queries realizado."
}

# Función para imprimir los resultados
print_results() {
    echo_red_bold "\n\nFINAL RESULTS:"
    echo_red_bold "----------------------------------------"
    found=false
    for result in "${results[@]}"; do
        if [[ $result == *"NOT FOUND"* ]]; then
            echo "-----> $result"
            found=true
        fi
    done
    if [ "$found" = false ]; then
        echo_green "All metadata is in the organization."
    fi
}

# Función para limpiar archivos temporales
cleanup_files() {
    if [[ $keep_metadata_json == false ]]; then
        rm -f extractedMetadata.json
    fi

    # if [[ $keep_query_results == false ]]; then
    #     rm -f result.json
    # fi
}

#-------------------------------------------------------------------------------------------------
# L Ó G I C A  Y  F U N C I O N A M I E N T O
#-------------------------------------------------------------------------------------------------
# Inicializar variables para los parámetros
metadata_name=""
target_org=""
metadata_type=""
keep_metadata_json=false
keep_query_results=false

# Declarar un array para almacenar los resultados
declare -a results
# Declarar un array asociativo para almacenar los valores procesados
declare -A processed_values
# Declarar un array asociativo para almacenar la metadata
declare -A metadata

main() {
    process_arguments "$@"
    # Verificar si se han proporcionado los parámetros necesarios
    check_parameters
    # Verificar e instalar jq si no está instalado
    install_jq
    # Asignar el tipo de metadato y definir file_path y patterns según el tipo
    set_metadata_type
    # Leer el archivo línea por línea
    extract_metadata
    # Guardar la metadata extraída en JSON como arrays y con un formato legible
    save_metadata_to_json
    # Realizar las consultas agrupadas y verificar los resultados
    perform_queries
    print_results
    cleanup_files
}

main "$@"
