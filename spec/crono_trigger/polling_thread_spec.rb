require "spec_helper"

RSpec.describe CronoTrigger::PollingThread do
  let(:notification1) do
    Notification.create!(
      name: "notification1",
      cron: "0,30 * * * *",
      started_at: Time.current,
    ).tap(&:activate_schedule!)
  end
  let(:notification2) do
    Notification.create!(
      name: "notification2",
      cron: "10 * * * *",
      started_at: Time.current,
    ).tap(&:activate_schedule!)
  end
  let(:notification3) do
    Notification.create!(
      name: "notification3",
      cron: "*/10 * * * *",
      started_at: Time.current,
    ).tap(&:activate_schedule!)
  end
  let(:notification4) do
    Notification.create!(
      name: "notification4",
      cron: "*/10 * * * *",
      started_at: Time.current,
    ).tap(&:activate_schedule!)
  end

  describe "#poll" do
    subject(:polling_thread) { CronoTrigger::PollingThread.new(Queue.new, ServerEngine::BlockingFlag.new, Logger.new($stdout), executor) }

    let(:executor) { Concurrent::ImmediateExecutor.new }

    it "execute model#execute method" do
      Timecop.freeze(Time.utc(2017, 6, 18, 1, 0)) do
        notification1
        notification2
        notification3
        notification4.update(finished_at: Time.current + 1)
      end

      Timecop.freeze(Time.utc(2017, 6, 18, 1, 10)) do
        expect {
          polling_thread.poll(Notification)
        }.to change { Notification.results }.from({}).to({notification2.id => "executed", notification3.id => "executed"})
      end
    end

    if ENV["DB"] == "mysql"
      context "when MySQL is restarted after poll is called" do
        it "execute model#execute method without any errors" do
          Timecop.freeze(Time.utc(2017, 6, 18, 1, 0)) do
            notification1
            notification2
            notification3
            notification4.update(finished_at: Time.current + 1)
          end

          Timecop.freeze(Time.utc(2017, 6, 18, 1, 10)) do
            expect {
              th = Thread.start do
                polling_thread.poll(Notification)
                system(ENV["MYSQL_RESTART_COMMAND"])
                expect {
                  polling_thread.poll(Notification)
                }.to_not raise_error
              end
              th.join
            }.to change { Notification.results }.from({}).to({notification2.id => "executed", notification3.id => "executed"})
          end
        end
      end
    end
  end
end
