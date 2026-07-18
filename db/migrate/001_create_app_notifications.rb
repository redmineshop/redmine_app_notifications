# frozen_string_literal: true

class CreateAppNotifications < ActiveRecord::Migration[6.1]
  def up
    create_table :app_notifications do |t|
      t.datetime :created_on
      t.boolean :viewed, default: false, null: false
      t.integer :journal_id
      t.integer :issue_id
      t.integer :author_id
      t.integer :recipient_id
    end

    add_index :app_notifications, :journal_id
    add_index :app_notifications, :issue_id
    add_index :app_notifications, :author_id
    add_index :app_notifications, :recipient_id
    add_index :app_notifications, %i[recipient_id viewed]
  end

  def down
    drop_table :app_notifications
  end
end
