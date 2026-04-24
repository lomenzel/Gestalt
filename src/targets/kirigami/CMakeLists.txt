cmake_minimum_required(VERSION 3.20)


set(APP_NAME $ENV{APP_NAME})
set(APP_TITLE $ENV{APP_TITLE})

project(${APP_NAME})


find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)
include(ECMQmlModule)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    Test
    Gui
    QuickControls2
    Widgets
)

find_package(KF6 REQUIRED COMPONENTS
    Kirigami
    I18n
    CoreAddons
    QQC2DesktopStyle
    IconThemes
)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)

configure_file( appname.gestalt.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/${APP_NAME}.gestalt.desktop )

add_subdirectory(src)

install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${APP_NAME}.gestalt.desktop DESTINATION ${KDE_INSTALL_APPDIR})

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
