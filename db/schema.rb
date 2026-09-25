# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_25_140000) do
  create_table "deliveries", force: :cascade do |t|
    t.string "item_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_key"], name: "index_deliveries_on_item_key", unique: true
  end

  create_table "dismissals", force: :cascade do |t|
    t.string "item_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_key"], name: "index_dismissals_on_item_key", unique: true
  end

  create_table "github_notifications", force: :cascade do |t|
    t.string "thread_id", null: false
    t.string "reason", null: false
    t.string "pr_key"
    t.string "title"
    t.string "actor"
    t.text "body"
    t.datetime "occurred_at", null: false
    t.datetime "read_at"
    t.datetime "resolved_at"
    t.string "resolution"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["occurred_at"], name: "index_github_notifications_on_occurred_at"
    t.index ["pr_key"], name: "index_github_notifications_on_pr_key"
    t.index ["thread_id"], name: "index_github_notifications_on_thread_id", unique: true
  end

  create_table "github_pull_requests", force: :cascade do |t|
    t.string "key", null: false
    t.json "data", default: {}, null: false
    t.boolean "mine", default: false, null: false
    t.boolean "requested_from_me", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_github_pull_requests_on_key", unique: true
  end

  create_table "jira_notifications", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "kind", null: false
    t.string "ticket_key", null: false
    t.string "actor"
    t.text "body"
    t.datetime "occurred_at", null: false
    t.datetime "read_at"
    t.datetime "resolved_at"
    t.string "resolution"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_jira_notifications_on_external_id", unique: true
    t.index ["occurred_at"], name: "index_jira_notifications_on_occurred_at"
    t.index ["ticket_key"], name: "index_jira_notifications_on_ticket_key"
  end

  create_table "jira_tickets", force: :cascade do |t|
    t.string "key", null: false
    t.string "title"
    t.string "issue_type"
    t.string "status"
    t.string "status_category"
    t.string "priority"
    t.string "assignee"
    t.boolean "assigned_to_me", default: false, null: false
    t.string "reporter"
    t.boolean "watching", default: false, null: false
    t.string "sprint"
    t.text "description"
    t.datetime "jira_updated_at"
    t.datetime "comments_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reported_by_me", default: false, null: false
    t.index ["key"], name: "index_jira_tickets_on_key", unique: true
  end

  create_table "review_comments", force: :cascade do |t|
    t.integer "review_id", null: false
    t.string "path", null: false
    t.integer "line", null: false
    t.string "side", default: "RIGHT", null: false
    t.integer "start_line"
    t.text "body", null: false
    t.string "state", default: "staged", null: false
    t.string "author", default: "you", null: false
    t.string "severity"
    t.json "notes", default: [], null: false
    t.boolean "asking", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "evidence"
    t.index ["review_id"], name: "index_review_comments_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "pr_key", null: false
    t.string "head_sha"
    t.string "status", default: "draft", null: false
    t.string "ai_status", default: "idle", null: false
    t.text "ai_error"
    t.text "summary"
    t.string "event"
    t.datetime "sent_at"
    t.string "github_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "ai_report"
    t.index ["pr_key"], name: "index_reviews_on_pr_key"
  end

  create_table "session_signals", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "needs"
    t.datetime "needs_at"
    t.string "last_event"
    t.datetime "last_event_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_session_signals_on_session_id", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "spawned_agents", force: :cascade do |t|
    t.integer "pid", null: false
    t.string "purpose", null: false
    t.string "ref"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pid"], name: "index_spawned_agents_on_pid"
  end

  add_foreign_key "review_comments", "reviews"
end
