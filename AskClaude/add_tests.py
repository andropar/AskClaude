#!/usr/bin/env python3
"""
Script to add a test target to the AskClaude Xcode project.
This modifies the project.pbxproj file to include the test target and test files.
"""

import sys
import uuid
import os

def generate_uuid():
    """Generate a UUID in Xcode format (24 hex characters)"""
    return uuid.uuid4().hex[:24].upper()

def add_test_target(pbxproj_path):
    """Add test target to the Xcode project"""

    # Check if file exists
    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        return False

    # Read the project file
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Check if tests already exist
    if 'AskClaudeTests' in content:
        print("Test target already exists in project")
        return True

    # Generate UUIDs for various project elements
    test_target_uuid = generate_uuid()
    test_file_ref_uuid = generate_uuid()
    test_build_file_uuid = generate_uuid()
    test_product_ref_uuid = generate_uuid()
    test_dependency_uuid = generate_uuid()
    test_native_target_uuid = generate_uuid()
    test_build_config_debug_uuid = generate_uuid()
    test_build_config_release_uuid = generate_uuid()
    test_config_list_uuid = generate_uuid()
    test_sources_phase_uuid = generate_uuid()
    test_frameworks_phase_uuid = generate_uuid()
    test_resources_phase_uuid = generate_uuid()
    test_container_proxy_uuid = generate_uuid()

    print(f"Generated UUIDs for test target")

    # Find the main target UUID (AskClaude app)
    import re
    main_target_match = re.search(r'([A-F0-9]{24}) /\* AskClaude \*/ = \{[^}]*isa = PBXNativeTarget', content)
    if not main_target_match:
        print("Error: Could not find main AskClaude target")
        return False

    main_target_uuid = main_target_match.group(1)
    print(f"Found main target UUID: {main_target_uuid}")

    # Create backup
    backup_path = pbxproj_path + '.backup'
    with open(backup_path, 'w') as f:
        f.write(content)
    print(f"Created backup at {backup_path}")

    # Build the modifications (we'll insert them at appropriate locations)

    # 1. Add PBXBuildFile section entry
    build_file_entry = f"\t\t{test_build_file_uuid} /* ClaudeOutputParserTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {test_file_ref_uuid} /* ClaudeOutputParserTests.swift */; }};\n"

    # 2. Add PBXFileReference entry
    file_ref_entry = f"\t\t{test_file_ref_uuid} /* ClaudeOutputParserTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClaudeOutputParserTests.swift; sourceTree = \"<group>\"; }};\n"
    file_ref_entry += f"\t\t{test_product_ref_uuid} /* AskClaudeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AskClaudeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n"

    # 3. Add PBXNativeTarget entry
    native_target_entry = f"""	{test_native_target_uuid} /* AskClaudeTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {test_config_list_uuid} /* Build configuration list for PBXNativeTarget "AskClaudeTests" */;
			buildPhases = (
				{test_sources_phase_uuid} /* Sources */,
				{test_frameworks_phase_uuid} /* Frameworks */,
				{test_resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{test_dependency_uuid} /* PBXTargetDependency */,
			);
			name = AskClaudeTests;
			productName = AskClaudeTests;
			productReference = {test_product_ref_uuid} /* AskClaudeTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
"""

    # 4. Add XCBuildConfiguration entries
    build_config_debug = f"""		{test_build_config_debug_uuid} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.askclaude.AskClaudeTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AskClaude.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AskClaude";
			}};
			name = Debug;
		}};
"""

    build_config_release = f"""		{test_build_config_release_uuid} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.askclaude.AskClaudeTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AskClaude.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AskClaude";
			}};
			name = Release;
		}};
"""

    # 5. Add XCConfigurationList
    config_list = f"""		{test_config_list_uuid} /* Build configuration list for PBXNativeTarget "AskClaudeTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{test_build_config_debug_uuid} /* Debug */,
				{test_build_config_release_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
"""

    # 6. Add build phases
    sources_phase = f"""		{test_sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{test_build_file_uuid} /* ClaudeOutputParserTests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

    frameworks_phase = f"""		{test_frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

    resources_phase = f"""		{test_resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

    # 7. Add target dependency
    target_dependency = f"""		{test_dependency_uuid} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {main_target_uuid} /* AskClaude */;
			targetProxy = {test_container_proxy_uuid} /* PBXContainerItemProxy */;
		}};
"""

    # 8. Add container item proxy
    container_proxy = f"""		{test_container_proxy_uuid} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = EEE000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {main_target_uuid};
			remoteInfo = AskClaude;
		}};
"""

    # 9. Add PBXGroup for test files
    test_group = f"""		{generate_uuid()} /* AskClaudeTests */ = {{
			isa = PBXGroup;
			children = (
				{test_file_ref_uuid} /* ClaudeOutputParserTests.swift */,
			);
			path = AskClaudeTests;
			sourceTree = "<group>";
		}};
"""

    print("WARNING: Automatic modification of pbxproj files is complex and error-prone.")
    print("It's recommended to add the test target manually using Xcode:")
    print()
    print("1. Open AskClaude.xcodeproj in Xcode")
    print("2. File > New > Target")
    print("3. Select 'Unit Testing Bundle'")
    print("4. Name it 'AskClaudeTests'")
    print("5. Delete the auto-generated test file")
    print("6. Add the existing AskClaudeTests folder to the project")
    print()
    print("The test files are ready at: AskClaudeTests/ClaudeOutputParserTests.swift")

    return False  # Don't actually modify the file

if __name__ == '__main__':
    pbxproj_path = 'AskClaude.xcodeproj/project.pbxproj'
    add_test_target(pbxproj_path)
