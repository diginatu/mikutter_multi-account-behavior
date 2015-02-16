# -*- coding: utf-8 -*-

class Multi_account_behavior
  @tring_send_postbox
  @num_received = 0
  @num_service = 1000
  @best_account
  @best_score = 0
  @current_score
  @post_gui

  def receiveRelation (me, rel)
    @num_received += 1
    t_status = [rel[:following], rel[:followed_by]]
    prior = UserConfig[:multi_account_behavior_prior_condition]
    t_score = (t_status[prior]?2:0) + (t_status[1-prior]?1:0)
    if t_score > @best_score
      @best_score = t_score
      @best_account = me
    end

    if me == Service.primary.user_obj
      if !UserConfig[:multi_account_behavior_confirm_better]
        if t_score >= 2
          p "now tweet!!"
          Plugin.create(:gtk).widgetof(@tring_send_postbox).post_it
        end
      end
      @current_score = t_score
    end

    print @num_received, "<=", @num_service, "\n"
    if @num_service == @num_received
      if @best_score > @current_score
        p "best tweet"
        p @best_account
      else
        p "now tweet"
        Plugin.create(:gtk).widgetof(@tring_send_postbox).post_it
      end
    end
  end

  def set_num_service num
    @num_service = num
  end

  def reset (postbox)
    @tring_send_postbox = postbox
    @num_received = 0
    @best_score = 0
  end
end

multi_account_behavior = Multi_account_behavior.new

Plugin.create(:multi_account_behavior) do
  UserConfig[:multi_account_behavior_prior_condition] ||= 0
  UserConfig[:multi_account_behavior_confirm_better]  ||= false

  settings("マルチアカウント誤爆注意") do
    select("優先条件", :multi_account_behavior_prior_condition, { 0 => "フォローしている", 1 => "フォローされている"})
    settings("現在のアカウントが優先条件を満たしていても") do
      boolean("より良いアカウントがあれば確認する", :multi_account_behavior_confirm_better)
    end

    about("about", {
      :name => "multi account behavior",
      :version => "1.0",
      :comments => "適切でなさそうなアカウントでのリプやファボを抑制します",
      :authors => ["@diginatu"]
    })
  end

  filter_gui_postbox_post do |gui_postbox|
    text = Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text

    if /^@([a-zA-Z0-9_]*) / =~ text
      p "rep tweet"
      activity :system, $1
      user = User.findbyidname($1, 1)

      if Service.any? { |me| me.user_obj == user }
        p "one_of_mine"
        [gui_postbox]
      else
        multi_account_behavior.reset(gui_postbox)
        service_count = 0
        Service.each{ |me|
          p me.user_obj
          Service.primary.friendship(target_id: user[:id], source_id: me.user_obj[:id]).next{ |rel|
            if rel
              p "success"
              multi_account_behavior.receiveRelation(me.user_obj, rel)
            end
          }.terminate.trap{
            p "failed"
          }
          service_count += 1
        }

        multi_account_behavior.set_num_service service_count

        p "reserved"
        []
      end

    else
      p "no rep tweet"
      [gui_postbox]
    end
  end

end
