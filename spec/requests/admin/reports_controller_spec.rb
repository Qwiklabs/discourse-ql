# frozen_string_literal: true

RSpec.describe Admin::ReportsController do
  it "is a subclass of AdminController" do
    expect(Admin::ReportsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    before do
      sign_in(admin)
    end

    describe '#bulk' do
      context "valid params" do
        it "renders the reports as JSON" do
          Fabricate(:topic)
          get "/admin/reports/bulk.json", params: {
            reports: {
              topics: { limit: 10 },
              likes: { limit: 10 }
            }
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body["reports"].count).to eq(2)
        end
      end

      context "invalid params" do
        context "nonexistent report" do
          it "returns not found reports" do
            get "/admin/reports/bulk.json", params: {
              reports: {
                topics: { limit: 10 },
                not_found: { limit: 10 }
              }
            }

            expect(response.status).to eq(200)
            expect(response.parsed_body["reports"].count).to eq(2)
            expect(response.parsed_body["reports"][0]["type"]).to eq("topics")
            expect(response.parsed_body["reports"][1]["type"]).to eq("not_found")
          end
        end

        context "invalid start or end dates" do
          it "doesn't return 500 error" do
            get "/admin/reports/bulk.json", params: {
              reports: {
                topics: { limit: 10, start_date: "2015-0-1" }
              }
            }
            expect(response.status).to eq(400)

            get "/admin/reports/bulk.json", params: {
              reports: {
                topics: { limit: 10, end_date: "2015-0-1" }
              }
            }
            expect(response.status).to eq(400)
          end
        end
      end
    end

    describe '#show' do
      context "invalid id form" do
        let(:invalid_id) { "!!&asdfasdf" }

        it "returns 404" do
          get "/admin/reports/#{invalid_id}.json"
          expect(response.status).to eq(404)
        end
      end

      context "valid type form" do
        context 'missing report' do
          it "returns a 404 error" do
            get "/admin/reports/nonexistent.json"
            expect(response.status).to eq(404)
          end
        end

        context 'a report is found' do
          it "renders the report as JSON" do
            Fabricate(:topic)
            get "/admin/reports/topics.json"

            expect(response.status).to eq(200)
            expect(response.parsed_body["report"]["total"]).to eq(1)
          end
        end
      end

      describe 'when report is scoped to a category' do
        fab!(:category) { Fabricate(:category) }
        fab!(:topic) { Fabricate(:topic, category: category) }
        fab!(:other_topic) { Fabricate(:topic) }

        it 'should render the report as JSON' do
          get "/admin/reports/topics.json", params: { category_id: category.id }

          expect(response.status).to eq(200)

          report = response.parsed_body["report"]

          expect(report["type"]).to eq('topics')
          expect(report["data"].count).to eq(1)
        end
      end

      describe 'when report is scoped to a group' do
        fab!(:user) { Fabricate(:user) }
        fab!(:other_user) { Fabricate(:user) }
        fab!(:group) { Fabricate(:group) }

        it 'should render the report as JSON' do
          group.add(user)

          get "/admin/reports/signups.json", params: { group_id: group.id }

          expect(response.status).to eq(200)

          report = response.parsed_body["report"]

          expect(report["type"]).to eq('signups')
          expect(report["data"].count).to eq(1)
        end
      end
    end
  end
end
