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

ActiveRecord::Schema[7.1].define(version: 2025_12_14_083016) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "shift_assignments", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "shift_month_id", null: false
    t.date "date", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shift_month_id"], name: "index_shift_assignments_on_shift_month_id"
    t.index ["staff_id", "shift_month_id", "date"], name: "idx_on_staff_id_shift_month_id_date_7a5c01a4e3", unique: true
    t.index ["staff_id"], name: "index_shift_assignments_on_staff_id"
  end

  create_table "shift_months", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "month", null: false
    t.integer "required_day_shifts", null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shift_requests", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "shift_month_id", null: false
    t.date "date", null: false
    t.string "kind", default: "off", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shift_month_id"], name: "index_shift_requests_on_shift_month_id"
    t.index ["staff_id", "shift_month_id", "date"], name: "index_shift_requests_on_staff_id_and_shift_month_id_and_date", unique: true
    t.index ["staff_id"], name: "index_shift_requests_on_staff_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "shift_assignments", "shift_months"
  add_foreign_key "shift_assignments", "staffs"
  add_foreign_key "shift_requests", "shift_months"
  add_foreign_key "shift_requests", "staffs"
end
