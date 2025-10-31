#!/bin/bash
#
# Mustache-Light Template Engine for Expose
# 
# Implements core Mustache features needed for static site generation:
# - Variables: {{var}}
# - Sections: {{#var}}...{{/var}}
# - Inverted Sections: {{^var}}...{{/var}}
# - Comments: {{! comment }}
#
# Design decisions:
# - Uses associative array (cleaner namespace than env vars)
# - Templates are collapsed to single line (like expose.sh already does)
# - Uses printf instead of echo (safer, no newline issues)
# - Learned from 'mo' but simplified for expose's needs

# Global associative array for template variables
declare -gA TEMPLATE_VARS=()

# Set a template variable
# Usage: template_set "key" "value"
template_set() {
    local key="$1"
    local value="$2"
    TEMPLATE_VARS["$key"]="$value"
}

# Get a template variable value
# Usage: template_get "key"
template_get() {
    local key="$1"
    printf '%s' "${TEMPLATE_VARS[$key]:-}"
}

# Clear all template variables
# Usage: template_clear
template_clear() {
    TEMPLATE_VARS=()
}

# Batch set variables from key:value pairs
# Usage: template_set_batch "key1:value1" "key2:value2" ...
template_set_batch() {
    local key value
    for assignment in "$@"; do
        if [[ "$assignment" == *":"* ]]; then
            key="${assignment%%:*}"
            value="${assignment#*:}"
            template_set "$key" "$value"
        fi
    done
}

# Check if a value is "truthy" (non-empty and not false)
# Usage: is_truthy "value"
is_truthy() {
    local value="$1"
    
    # Empty string is falsy
    [ -z "$value" ] && return 1
    
    # Literal "false" is falsy
    [ "$value" = "false" ] && return 1
    
    # "0" is falsy
    [ "$value" = "0" ] && return 1
    
    # Everything else is truthy
    return 0
}

# Replace simple variables {{var}} in template
# Uses TEMPLATE_VARS associative array
# Usage: template_replace_vars "template_string"
template_replace_vars() {
    local template="$1"
    local result="$template"
    local key value escaped_value
    
    # For each variable in TEMPLATE_VARS
    for key in "${!TEMPLATE_VARS[@]}"; do
        value="${TEMPLATE_VARS[$key]}"
        
        # Escape special characters for sed (learned from mo's approach)
        # Remove newlines from value (templates are single-line in expose)
        escaped_value=$(printf '%s' "$value" | tr -d '\n' | sed -e 's/[\/&]/\\&/g')
        
        # Replace {{key}} and {{key:default}} with value
        result=$(printf '%s' "$result" | sed -e "s/{{$key}}/$escaped_value/g" -e "s/{{$key:[^}]*}}/$escaped_value/g")
    done
    
    printf '%s' "$result"
}

# Process Mustache sections {{#var}}...{{/var}}
# Renders content if variable is truthy
# Usage: template_process_sections "template_string"
template_process_sections() {
    local template="$1"
    local result="$template"
    local key value
    
    # Process each variable that might have a section
    for key in "${!TEMPLATE_VARS[@]}"; do
        value="${TEMPLATE_VARS[$key]}"
        
        # Check if template contains this section
        if printf '%s' "$result" | grep -q "{{#$key}}"; then
            if is_truthy "$value"; then
                # Variable is truthy - keep content, remove section tags
                # Note: Templates are single-line so we can use simpler regex
                result=$(printf '%s' "$result" | sed -e "s/{{#$key}}\(.*\){{\\/$key}}/\1/g")
            else
                # Variable is falsy - remove entire section including content
                result=$(printf '%s' "$result" | sed -e "s/{{#$key}}.*{{\\/$key}}//g")
            fi
        fi
    done
    
    printf '%s' "$result"
}

# Process Mustache inverted sections {{^var}}...{{/var}}
# Renders content if variable is falsy
# Usage: template_process_inverted "template_string"
template_process_inverted() {
    local template="$1"
    local result="$template"
    local key value
    
    # Process each variable that might have an inverted section
    for key in "${!TEMPLATE_VARS[@]}"; do
        value="${TEMPLATE_VARS[$key]}"
        
        # Check if template contains this inverted section
        if printf '%s' "$result" | grep -q "{{^$key}}"; then
            if is_truthy "$value"; then
                # Variable is truthy - remove entire section
                result=$(printf '%s' "$result" | sed -e "s/{{^$key}}.*{{\\/$key}}//g")
            else
                # Variable is falsy - keep content, remove section tags
                result=$(printf '%s' "$result" | sed -e "s/{{^$key}}\(.*\){{\\/$key}}/\1/g")
            fi
        fi
    done
    
    printf '%s' "$result"
}

# Remove Mustache comments {{! comment }}
# Usage: template_remove_comments "template_string"
template_remove_comments() {
    local template="$1"
    # Single-line templates: simpler regex without multiline flag
    printf '%s' "$template" | sed -e 's/{{!.*}}//g'
}

# Main template rendering function
# Processes template with all Mustache features
# Usage: template_render "template_string"
template_render() {
    local template="$1"
    local result="$template"
    
    # 1. Remove comments first (they should never be rendered)
    result=$(template_remove_comments "$result")
    
    # 2. Process sections (conditional blocks)
    result=$(template_process_sections "$result")
    
    # 3. Process inverted sections
    result=$(template_process_inverted "$result")
    
    # 4. Replace variables
    result=$(template_replace_vars "$result")
    
    # 5. Clean up any remaining unused template variables
    result=$(printf '%s' "$result" | sed -e 's/{{[^}]*}}//g')
    
    printf '%s' "$result"
}

# Batch set variables from key:value pairs
# Usage: template_set_batch "key1:value1" "key2:value2" ...
template_set_batch() {
    for assignment in "$@"; do
        if [[ "$assignment" == *":"* ]]; then
            local key="${assignment%%:*}"
            local value="${assignment#*:}"
            template_set "$key" "$value"
        fi
    done
}

# Render template file with current variables
# Usage: template_render_file "path/to/template.html"
template_render_file() {
    local template_file="$1"
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi
    
    local template=$(cat "$template_file")
    template_render "$template"
}
