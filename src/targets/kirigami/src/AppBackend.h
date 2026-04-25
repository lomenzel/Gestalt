#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <vector>

#include "app.hpp"

class AppBackend : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString title READ title NOTIFY viewChanged)
  Q_PROPERTY(QVariantList sections READ sections NOTIFY viewChanged)

public:
  explicit AppBackend(QObject *parent = nullptr);

  QString title() const;
  QVariantList sections() const;

  Q_INVOKABLE void invokeAction(int actionIndex);

Q_SIGNALS:
  void viewChanged();

private:
  void updateView();
  QVariant valueToVariant(const Value &v) const;

  Value m_state;
  QString m_title;
  QVariantList m_sections;
  std::vector<Value> m_actionCallbacks;
};
