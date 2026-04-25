#include "AppBackend.h"
#include <QDebug>

AppBackend::AppBackend(QObject *parent) : QObject(parent) {
  m_state = app::initialState;
  updateView();
}

QVariant AppBackend::valueToVariant(const Value &v) const {
  v.force();
  if (v.isNull())
    return QVariant();
  if (v.isBool())
    return v.asBool();
  if (v.isInt())
    return static_cast<qlonglong>(v.asInt());
  if (v.isFloat())
    return v.asFloat();
  if (v.isString())
    return QString::fromStdString(v.asString());
  if (v.isList()) {
    QVariantList list;
    for (const auto &e : v.asList())
      list.append(valueToVariant(e));
    return list;
  }
  if (v.isSet()) {
    QVariantMap map;
    for (const auto &[k, val] : v.asSet()) {
      if (val.isFunction())
        continue;
      map[QString::fromStdString(k)] = valueToVariant(val);
    }
    return map;
  }
  return QVariant();
}

void AppBackend::updateView() {
  m_actionCallbacks.clear();

  Value viewTree = app::view(m_state);

  // Extract title
  if (viewTree.hasAttr("title")) {
    m_title = QString::fromStdString(viewTree["title"].asString());
  } else {
    m_title = QStringLiteral("Untitled");
  }

  // Extract sections
  m_sections.clear();
  if (viewTree.hasAttr("sections")) {
    for (const auto &section : viewTree["sections"].asList()) {
      QVariantMap sectionMap;
      sectionMap[QStringLiteral("name")] =
          QString::fromStdString(section["name"].asString());

      if (section.hasAttr("order") && !section["order"].isNull()) {
        sectionMap[QStringLiteral("order")] =
            static_cast<int>(section["order"].asInt());
      }

      const auto &content = section["content"];
      if (content.hasAttr("_type")) {
        QString type = QString::fromStdString(content["_type"].asString());
        sectionMap[QStringLiteral("contentType")] = type;

        if (type == QStringLiteral("displayValue")) {
          sectionMap[QStringLiteral("label")] =
              QString::fromStdString(content["label"].asString());
          sectionMap[QStringLiteral("value")] =
              QString::fromStdString(content["value"].asString());
          if (content.hasAttr("tooltip") && content["tooltip"].isString()) {
            sectionMap[QStringLiteral("tooltip")] =
                QString::fromStdString(content["tooltip"].asString());
          }
        } else if (type == QStringLiteral("actionGroup")) {
          QVariantList actions;
          for (const auto &action : content["actions"].asList()) {
            QVariantMap actionMap;
            actionMap[QStringLiteral("name")] =
                QString::fromStdString(action["name"].asString());
            actionMap[QStringLiteral("actionIndex")] =
                static_cast<int>(m_actionCallbacks.size());

            if (action.hasAttr("tooltip") && action["tooltip"].isString()) {
              actionMap[QStringLiteral("tooltip")] =
                  QString::fromStdString(action["tooltip"].asString());
            }
            if (action.hasAttr("id") && action["id"].isString()) {
              actionMap[QStringLiteral("id")] =
                  QString::fromStdString(action["id"].asString());
            }

            // Store the onClick callback
            if (action.hasAttr("onClick")) {
              m_actionCallbacks.push_back(action["onClick"]);
            }

            actions.append(actionMap);
          }
          sectionMap[QStringLiteral("actions")] = actions;
        }
      }

      m_sections.append(sectionMap);
    }
  }

  Q_EMIT viewChanged();
}

QString AppBackend::title() const { return m_title; }

QVariantList AppBackend::sections() const { return m_sections; }

void AppBackend::invokeAction(int actionIndex) {
  if (actionIndex < 0 ||
      actionIndex >= static_cast<int>(m_actionCallbacks.size())) {
    qWarning() << "Invalid action index:" << actionIndex;
    return;
  }

  Value result = m_actionCallbacks[actionIndex](m_state);

  if (result.hasAttr("state")) {
    m_state = m_state.update(result["state"]);
  } else {
    // Filter out effect key if present, merge the rest as state
    if (result.hasAttr("effect")) {
      Value cleaned =
          result.removeAttrs(Value::fromList({Value::fromString("effect")}));
      if (!cleaned.asSet().empty()) {
        m_state = m_state.update(cleaned);
      }
    } else {
      m_state = m_state.update(result);
    }
  }

  updateView();
}
