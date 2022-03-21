# frozen_string_literal: true

class CreateCandidates < ActiveRecord::Migration[7.0]
  def change
    create_table :candidates do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name

      t.timestamps
    end
  end
end
