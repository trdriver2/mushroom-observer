# encoding: utf-8
module PivotalHelper

  # From pivotal_tracker_helper.rb
  def pivotal_vote_controls(story)
    current_vote = story.user_vote(@user)
    result = ''.html_safe
    result << if @user && current_vote < MO.pivotal_max_vote
      link_to_function(image_tag('vote_up_hot.png'),
        "vote_on_story(#{story.id}, #{@user.id}, #{current_vote+1})")
    else
      image_tag('vote_up_cold.png')
    end
    result << content_tag(:span, story.score.to_s, :id => "pivotal_vote_num_#{story.id}")
    result << if @user && current_vote > MO.pivotal_min_vote
      link_to_function(image_tag('vote_down_hot.png'),
        "vote_on_story(#{story.id}, #{@user.id}, #{current_vote-1})")
    else
      image_tag('vote_down_cold.png')
    end
    return result
  end

  def pivotal_story(story)
    result = content_tag(:p, :DESCRIPTION.l + ':', :class => 'pivotal_heading')
    result += story.description.tp
    if story.user.instance_of?(User)
      result += content_tag(:p, :pivotal_posted_by.l + ': ' + user_link(story.user),
                            :class => 'pivotal_heading')
    end
    result += content_tag(:p, :COMMENTS.l + ':', :class => 'pivotal_heading')
    comments = []
    num = 0
    for comment in story.comments
      num += 1
      comments << pivotal_comment(comment, num)
    end
    result += content_tag(:div, comments.safe_join, :id => 'pivotal_comments')
    form = content_tag(:textarea, '', :id => 'pivotal_comment', :cols => 80, :rows => 10) + safe_br
    form += tag(:input, :type => :button, :value => :pivotal_post_comment.l,
                :onclick => "post_comment(#{story.id})")
    result += content_tag(:form, form, :action => '', :style => 'margin-top:1em')
    return result
  end

  def pivotal_comment(comment, num)
    content_tag(:div, :class => 'ListLine' + (num & 1).to_s) do
      content_tag(:p) do
        :CREATED.t + ': ' + comment.time.to_s + safe_br +
        :BY.t + ': ' + user_link(comment.user) + safe_br
      end + comment.text.to_s.tp
    end
  end
end