/*!
* \file
* \brief canitemdelegate.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Pauli Oikkonen <pauli.oikkonen@link-motion.com>
*
* any other legal text to be defined later
*/

#ifndef CANITEMDELEGATE_H
#define CANITEMDELEGATE_H

#include "mainwindow.h"
#include <QWidget>
#include <QStyledItemDelegate>

class CANItemDelegate : public QStyledItemDelegate
{
public:
    explicit CANItemDelegate(QObject *parent = NULL);
    QWidget * createEditor(QWidget *parent, const QStyleOptionViewItem &option, const QModelIndex &index) const;
    void paint(QPainter *painter, const QStyleOptionViewItem &option, const QModelIndex &index) const;
    void setModelData(QWidget *editor, QAbstractItemModel *model, const QModelIndex &index) const;
    void setEditorData(QWidget *editor, const QModelIndex &index) const;
    bool editorEvent(QEvent *event, QAbstractItemModel *model, const QStyleOptionViewItem &option, const QModelIndex &index);
};

#endif // CANITEMDELEGATE_H
