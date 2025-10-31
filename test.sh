#!/bin/bash

# Expose Test Suite
# Automated tests for expose.sh functionality
# Add new test sections as features are developed

PROJECT="example.site"
OUTPUT_DIR="output/$PROJECT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_PASSED=0
TOTAL_FAILED=0
SECTION_PASSED=0
SECTION_FAILED=0

echo "=================================="
echo "Expose Test Suite"
echo "=================================="
echo ""

# Ensure completely clean environment
echo "🧹 Cleaning test environment..."
rm -rf "$OUTPUT_DIR"
rm -rf "cache/$PROJECT"
rm -rf ".cache/$PROJECT"
echo "✅ Test environment cleaned"
echo ""

# Clean build
echo "🔨 Running clean build..."
./expose.sh -c -p "$PROJECT" > /dev/null 2>&1

echo "✅ Clean build completed"
echo ""

# Helper function for test sections
test_section() {
    local section_name="$1"
    echo -e "${BLUE}▶ $section_name${NC}"
    SECTION_PASSED=0
    SECTION_FAILED=0
}

# Helper function for tests
test_assert() {
    local test_name="$1"
    local condition="$2"
    
    echo -n "  Testing: $test_name ... "
    
    if eval "$condition"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((SECTION_PASSED++))
        ((TOTAL_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        ((SECTION_FAILED++))
        ((TOTAL_FAILED++))
        return 1
    fi
}

# Helper to print section summary
test_section_summary() {
    echo -e "  ${BLUE}Section: $SECTION_PASSED passed, $SECTION_FAILED failed${NC}"
    echo ""
}

################################################################################
# Test Section: Basic Build
################################################################################
test_section "Basic Build Tests"

test_assert "All 13 galleries generated" \
    "[ \$(find '$OUTPUT_DIR' -name 'index.html' | wc -l) -eq 13 ]"

test_assert "CSS file copied to output" \
    "[ -f '$OUTPUT_DIR/main.css' ]"

test_assert "Root index.html exists" \
    "[ -f '$OUTPUT_DIR/index.html' ]"

test_assert "No template variables left in output" \
    "! grep -r '{{[a-z]*}}' '$OUTPUT_DIR' --include='*.html' --exclude='*-template.html' 2>/dev/null"

test_section_summary

################################################################################
# Test Section: Gallery Content Feature
################################################################################
test_section "Gallery Content Feature"

test_assert "Home gallery has gallery-intro section" \
    "grep -q 'gallery-intro' '$OUTPUT_DIR/index.html'"

test_assert "Home gallery Markdown rendered to HTML" \
    "grep -q '<h1>Welcome Home</h1>' '$OUTPUT_DIR/index.html'"

test_assert "Fireworks gallery has gallery-intro section" \
    "grep -q 'gallery-intro' '$OUTPUT_DIR/events/fireworks/index.html'"

test_assert "Fireworks YAML metadata processed" \
    "grep -q '<cite>Fireworks</cite>' '$OUTPUT_DIR/events/fireworks/index.html'"

test_assert "Racing gallery has NO gallery-intro (no content.md)" \
    "! grep -q 'gallery-intro' '$OUTPUT_DIR/events/racing/index.html'"

test_assert "Template variable {{gallerybody}} replaced" \
    "! grep -q '{{gallerybody}}' '$OUTPUT_DIR/index.html'"

INTRO_COUNT=$(find "$OUTPUT_DIR" -name "index.html" -exec grep -l "gallery-intro" {} \; | wc -l)
test_assert "Gallery-intro appears in exactly 3 galleries" \
    "[ $INTRO_COUNT -eq 3 ]"

test_assert "HTML structure: gallery-intro before gallery section" \
    "[ \$(cat '$OUTPUT_DIR/index.html' | tr ' ' '\n' | grep -n 'gallery-intro' | head -1 | cut -d: -f1) -lt \$(cat '$OUTPUT_DIR/index.html' | tr ' ' '\n' | grep -n 'class=\"gallery\"' | head -1 | cut -d: -f1) ]"

test_assert "No empty gallery-intro sections" \
    "! grep -o 'gallery-intro[^<]*</section>' '$OUTPUT_DIR/index.html' | grep -q 'gallery-intro></section>'"

test_assert "Markdown strong tags rendered" \
    "grep -q '<strong>' '$OUTPUT_DIR/index.html'"

test_section_summary

################################################################################
# Test Section: Conditional Gallery Section
################################################################################
test_section "Conditional Gallery Section"

test_assert "About page (no images) has NO gallery section" \
    "! grep -q 'class=\"gallery\"' '$OUTPUT_DIR/pages/about/index.html'"

test_assert "About page (no images) still has gallery-intro" \
    "grep -q 'gallery-intro' '$OUTPUT_DIR/pages/about/index.html'"

test_assert "Home gallery (with images) HAS gallery section" \
    "grep -q 'class=\"gallery\"' '$OUTPUT_DIR/index.html'"

test_assert "Racing gallery (with images) HAS gallery section" \
    "grep -q 'class=\"gallery\"' '$OUTPUT_DIR/events/racing/index.html'"

test_assert "Gear gallery (with images) HAS gallery section" \
    "grep -q 'class=\"gallery\"' '$OUTPUT_DIR/pages/gear/index.html'"

test_assert "Template variable {{gallery}} replaced" \
    "! grep -q '{{gallery}}' '$OUTPUT_DIR/index.html'"

GALLERY_COUNT=$(find "$OUTPUT_DIR" -name "index.html" -exec grep -l 'class=\"gallery\"' {} \; | wc -l)
test_assert "Gallery section appears in exactly 12 galleries (all with images)" \
    "[ $GALLERY_COUNT -eq 12 ]"

test_section_summary

################################################################################
# Test Section: SEO & Metadata (placeholder for future tests)
################################################################################
# test_section "SEO & Metadata"
# 
# test_assert "Meta description exists" \
#     "grep -q '<meta name=\"description\"' '$OUTPUT_DIR/index.html'"
# 
# test_section_summary

################################################################################
# Test Section: Navigation (placeholder for future tests)
################################################################################
# test_section "Navigation Structure"
# 
# test_assert "Navigation menu exists" \
#     "grep -q '<nav>' '$OUTPUT_DIR/index.html'"
# 
# test_section_summary

################################################################################
# Final Summary
################################################################################
echo "=================================="
echo "Test Results"
echo "=================================="
echo -e "Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed: ${RED}$TOTAL_FAILED${NC}"
echo "Total:  $((TOTAL_PASSED + TOTAL_FAILED))"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
