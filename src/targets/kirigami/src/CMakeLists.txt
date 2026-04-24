add_executable(${APP_NAME})

ecm_add_qml_module(${APP_NAME}
    URI
    org.kde.tutorial
)

target_sources(${APP_NAME}
    PRIVATE
    main.cpp
)

ecm_target_qml_sources(${APP_NAME}
    SOURCES
    Main.qml
)

target_link_libraries(${APP_NAME}
    PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    Qt6::QuickControls2
    Qt6::Widgets
    KF6::I18n
    KF6::CoreAddons
    KF6::IconThemes
)

install(TARGETS ${APP_NAME} ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
