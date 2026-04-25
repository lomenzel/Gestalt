#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>
#include <QtQml>

#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>

#include "AppBackend.h"

int main(int argc, char *argv[]) {
  KIconTheme::initTheme();
  QApplication qapp(argc, argv);
  KLocalizedString::setApplicationDomain("gestalt");

  QApplication::setOrganizationName(QStringLiteral("Gestalt"));
  QApplication::setApplicationName(
      QString::fromStdString(app::meta["name"].asString()));
  QApplication::setApplicationDisplayName(
      QString::fromStdString(app::meta["title"].asString()));

  QApplication::setStyle(QStringLiteral("breeze"));
  if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
    QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
  }

  QQmlApplicationEngine engine;

  AppBackend backend;
  engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
  engine.rootContext()->setContextObject(new KLocalizedContext(&engine));

  engine.loadFromModule("org.kde.tutorial", "Main");

  if (engine.rootObjects().isEmpty()) {
    return -1;
  }

  return qapp.exec();
}
