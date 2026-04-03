set(CPACK_PACKAGE_NAME "redis")

redis_parse_version(CPACK_PACKAGE_VERSION_MAJOR CPACK_PACKAGE_VERSION_MINOR CPACK_PACKAGE_VERSION_PATCH)

set(CPACK_PACKAGE_CONTACT "maintainers@lists.redis.io")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Redis is an open source (BSD) high-performance key/value datastore")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE.txt")
set(CPACK_RESOURCE_FILE_README "${CMAKE_SOURCE_DIR}/README.md")
set(CPACK_STRIP_FILES TRUE)

redis_get_distro_name(DISTRO_NAME)
message(STATUS "Current host distro: ${DISTRO_NAME}")

if (DISTRO_NAME MATCHES ubuntu
    OR DISTRO_NAME MATCHES debian
    OR DISTRO_NAME MATCHES mint)
    message(STATUS "Adding target package for ${DISTRO_NAME}")
    set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/redis")
    # Debian related parameters
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Redis contributors")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
    set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
    set(CPACK_GENERATOR "DEB")
endif ()

include(CPack)
unset(DISTRO_NAME CACHE)

# ---------------------------------------------------
# Create a helper script for creating symbolic links
# ---------------------------------------------------
write_file(
    ${CMAKE_BINARY_DIR}/CreateSymlink.sh
    "\
#!/bin/bash                                                 \n\
if [ -z \${DESTDIR} ]; then                                 \n\
    # Script is called during 'make install'                \n\
    PREFIX=${CMAKE_INSTALL_PREFIX}/bin                      \n\
else                                                        \n\
    # Script is called during 'make package'                \n\
    PREFIX=\${DESTDIR}${CPACK_PACKAGING_INSTALL_PREFIX}/bin \n\
fi                                                          \n\
cd \$PREFIX                                                 \n\
ln -sf \$1 \$2")

if (WIN32)
    message(STATUS "Adding target package for Windows")

    # Download Windows Service Wrapper
    if(NOT EXISTS "${CMAKE_BINARY_DIR}/redis-service.exe")
        file(DOWNLOAD "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe" 
             "${CMAKE_BINARY_DIR}/redis-service.exe" SHOW_PROGRESS)
    endif()

    # Look for redis-service.xml
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../build-repo/service/redis-service.xml")
        file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/../build-repo/service/redis-service.xml" DESTINATION "${CMAKE_BINARY_DIR}")
    else()
        file(WRITE "${CMAKE_BINARY_DIR}/redis-service.xml"
"<service>
  <id>Redis</id>
  <name>Redis Server</name>
  <description>Redis in-memory data structure store</description>
  <executable>%BASE%\\redis-server.exe</executable>
  <arguments>redis.conf</arguments>
  <log mode=\"roll\"></log>
  <onfailure action=\"restart\" delay=\"10 sec\"/>
</service>
")
    endif()

    install(PROGRAMS "${CMAKE_BINARY_DIR}/redis-service.exe" DESTINATION bin)
    install(FILES "${CMAKE_BINARY_DIR}/redis-service.xml" DESTINATION bin)

    set(CPACK_GENERATOR "ZIP;WIX;NSIS")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Redis")
    set(CPACK_WIX_UPGRADE_GUID "5E12E119-BEB5-4D05-8A5E-2A47CC31E3AC")

    # For NSIS: register the service during install
    set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS "
        ExecWait '\\\"$INSTDIR\\\\bin\\\\redis-service.exe\\\" install'
        ExecWait '\\\"$INSTDIR\\\\bin\\\\redis-service.exe\\\" start'
    ")
    set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS "
        ExecWait '\\\"$INSTDIR\\\\bin\\\\redis-service.exe\\\" stop'
        ExecWait '\\\"$INSTDIR\\\\bin\\\\redis-service.exe\\\" uninstall'
    ")

    # For WIX: setup custom actions to manage the service
    file(WRITE "${CMAKE_BINARY_DIR}/wix_patch.xml" "
<CPackWiXPatch>
    <CPackWiXFragment Id=\"#PRODUCT\">
        <CustomAction Id=\"InstallRedisService\" Directory=\"CM_DP_bin\" ExeCommand=\"[CM_DP_bin]redis-service.exe install\" Execute=\"deferred\" Impersonate=\"no\" Return=\"check\" />
        <CustomAction Id=\"StartRedisService\" Directory=\"CM_DP_bin\" ExeCommand=\"[CM_DP_bin]redis-service.exe start\" Execute=\"deferred\" Impersonate=\"no\" Return=\"check\" />
        <CustomAction Id=\"StopRedisService\" Directory=\"CM_DP_bin\" ExeCommand=\"[CM_DP_bin]redis-service.exe stop\" Execute=\"deferred\" Impersonate=\"no\" Return=\"ignore\" />
        <CustomAction Id=\"UninstallRedisService\" Directory=\"CM_DP_bin\" ExeCommand=\"[CM_DP_bin]redis-service.exe uninstall\" Execute=\"deferred\" Impersonate=\"no\" Return=\"ignore\" />

        <InstallExecuteSequence>
            <Custom Action=\"InstallRedisService\" Before=\"InstallFinalize\">NOT Installed</Custom>
            <Custom Action=\"StartRedisService\" After=\"InstallRedisService\">NOT Installed</Custom>
            <Custom Action=\"StopRedisService\" Before=\"RemoveFiles\">REMOVE=\"ALL\"</Custom>
            <Custom Action=\"UninstallRedisService\" After=\"StopRedisService\">REMOVE=\"ALL\"</Custom>
        </InstallExecuteSequence>
    </CPackWiXFragment>
</CPackWiXPatch>
")
    set(CPACK_WIX_PATCH_FILE "${CMAKE_BINARY_DIR}/wix_patch.xml")
endif()
