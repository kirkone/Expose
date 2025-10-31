#!/bin/bash

# Test suite for lib/template.sh

# Load the template library
source "$(dirname "$0")/../lib/template.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test helper
assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((FAILED++))
    fi
}

echo "Testing Mustache-Light Template Engine"
echo "======================================="
echo ""

# Test 1: Simple variable replacement
echo "Test: Simple Variables"
template_clear
template_set "name" "World"
result=$(template_render "Hello {{name}}!")
assert_equals "Simple variable" "Hello World!" "$result"

# Test 2: Multiple variables
template_clear
template_set "first" "John"
template_set "last" "Doe"
result=$(template_render "{{first}} {{last}}")
assert_equals "Multiple variables" "John Doe" "$result"

# Test 3: Section with truthy value
template_clear
template_set "show" "yes"
result=$(template_render "{{#show}}Visible{{/show}}")
assert_equals "Section with truthy value" "Visible" "$result"

# Test 4: Section with falsy value (empty)
template_clear
template_set "show" ""
result=$(template_render "{{#show}}Hidden{{/show}}")
assert_equals "Section with empty value" "" "$result"

# Test 5: Section with false
template_clear
template_set "show" "false"
result=$(template_render "{{#show}}Hidden{{/show}}")
assert_equals "Section with false" "" "$result"

# Test 6: Inverted section with truthy
template_clear
template_set "items" "yes"
result=$(template_render "{{^items}}No items{{/items}}")
assert_equals "Inverted section with truthy" "" "$result"

# Test 7: Inverted section with falsy
template_clear
template_set "items" ""
result=$(template_render "{{^items}}No items{{/items}}")
assert_equals "Inverted section with falsy" "No items" "$result"

# Test 8: Comments
template_clear
result=$(template_render "Before{{! this is a comment}}After")
assert_equals "Comments removed" "BeforeAfter" "$result"

# Test 9: Nested sections
template_clear
template_set "outer" "yes"
template_set "inner" "yes"
template_set "value" "Content"
result=$(template_render "{{#outer}}{{#inner}}{{value}}{{/inner}}{{/outer}}")
assert_equals "Nested sections" "Content" "$result"

# Test 10: Section with HTML content
template_clear
template_set "posts" "yes"
template_set "title" "Gallery"
result=$(template_render "{{#posts}}<section><h2>{{title}}</h2></section>{{/posts}}")
assert_equals "Section with HTML" "<section><h2>Gallery</h2></section>" "$result"

# Test 11: Section removes when empty (our gallery use case)
template_clear
template_set "posts" ""
template_set "title" "Gallery"
result=$(template_render "{{#posts}}<section><h2>{{title}}</h2></section>{{/posts}}")
assert_equals "Empty section removes HTML" "" "$result"

# Test 12: Batch variable setting
template_clear
template_set_batch "name:Alice" "age:30" "city:Berlin"
result=$(template_render "{{name}} is {{age}} years old and lives in {{city}}")
assert_equals "Batch variable setting" "Alice is 30 years old and lives in Berlin" "$result"

# Test 13: Unused variables are removed
template_clear
template_set "used" "value"
result=$(template_render "{{used}} {{unused}}")
assert_equals "Unused variables removed" "value " "$result"

# Test 14: Special characters in values
template_clear
template_set "path" "some/path/to/file"
template_set "email" "user@example.com"
result=$(template_render "{{path}} {{email}}")
assert_equals "Special characters escaped" "some/path/to/file user@example.com" "$result"

echo ""
echo "======================================="
echo "Results: $PASSED passed, $FAILED failed"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
