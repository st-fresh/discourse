require 'rails_helper'

describe PostTimestampChanger do
  describe "change!" do
    let(:old_timestamp) { Time.zone.now }
    let(:new_timestamp) { old_timestamp + 1.day }
    let!(:topic) { Fabricate(:topic, created_at: old_timestamp) }
    let!(:p1) { Fabricate(:post, topic: topic, created_at: old_timestamp) }
    let!(:p2) { Fabricate(:post, topic: topic, created_at: old_timestamp + 1.day) }
    let(:params) { { topic_id: topic.id, timestamp: new_timestamp.to_f } }

    it 'changes the timestamp of the topic and opening post' do
      PostTimestampChanger.new(params).change!

      topic.reload
      [:created_at, :updated_at, :bumped_at].each do |column|
        expect(topic.public_send(column)).to be_within_one_second_of(new_timestamp)
      end

      p1.reload
      [:created_at, :updated_at].each do |column|
        expect(p1.public_send(column)).to be_within_one_second_of(new_timestamp)
      end

      expect(topic.last_posted_at).to be_within_one_second_of(p2.reload.created_at)
    end

    describe 'predated timestamp' do
      it 'updates the timestamp of posts in the topic with the time difference applied' do
        PostTimestampChanger.new(params).change!

        p2.reload
        [:created_at, :updated_at].each do |column|
          expect(p2.public_send(column)).to be_within_one_second_of(old_timestamp + 2.day)
        end
      end
    end

    describe 'backdated timestamp' do
      let(:new_timestamp) { old_timestamp - 1.day }

      it 'updates the timestamp of posts in the topic with the time difference applied' do
        PostTimestampChanger.new(params).change!

        p2.reload
        [:created_at, :updated_at].each do |column|
          expect(p2.public_send(column)).to be_within_one_second_of(old_timestamp)
        end
      end
    end

    it 'deletes the stats cache' do
      $redis.set AdminDashboardData.stats_cache_key, "X"
      $redis.set About.stats_cache_key, "X"

      PostTimestampChanger.new(params).change!

      expect($redis.get(AdminDashboardData.stats_cache_key)).to eq(nil)
      expect($redis.get(About.stats_cache_key)).to eq(nil)
    end
  end
end
