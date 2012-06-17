# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class AbstractModelTest < UnitTestCase

  # Make sure update_view_stats updated stuff correctly (and did nothing else).
  def assert_same_but_view_stats(old_attrs, new_attrs, msg='')
    for key in (old_attrs.keys + new_attrs.keys).map(&:to_s).uniq.sort
      old_val = old_attrs[key]
      new_val = new_attrs[key]
      if key == 'num_views'
        assert_equal((old_val || 0) + 1, new_val, msg + "num_views wrong")
      elsif key == 'last_view'
        assert(new_val > 1.hour.ago, msg + "last_view more than one hour old")
        if old_val
          assert(new_val > old_val, msg + "last_view wasn't updated")
        end
      else
        assert_equal(old_val, new_val, msg + "#{key} shouldn't have changed!")
      end
    end
  end

  def assert_rss_log_lines(num, obj)
    clean_our_backtrace do
      assert_equal(num, obj.rss_log.notes.split("\n").length,
                   "Expected #{num} lines in rss log, got:\n" +
                   "<#{obj.rss_log.notes}>")
    end
  end

  def assert_rss_log_has_tag(expect_tag, obj)
    clean_our_backtrace do
      found = false
      for tag, args, time in obj.rss_log.parse_log
        if tag == expect_tag
          found = true
          break
        end
      end
      assert_block("Expected to find #{tag.inspect} in rss log, got:\n" +
                   "<#{obj.rss_log.notes}>") { found }
    end
  end

################################################################################

  # -------------------------------------------------------------------
  #  Make sure ActiveRecord and database are getting timezones right.
  # -------------------------------------------------------------------

  def test_time_zone
    now = Time.now
    obs = Observation.create(
      :created => now,
      :when    => now,
      :where   => 'local'
    )

    # Make sure it fails to save if no user logged in.
    assert_equal(1, obs.errors.length, 'Should not have saved without login.')
    assert_equal(:validate_observation_user_missing.t, obs.dump_errors)

    # Log Rolf in ang try again.
    User.current = @rolf
    obs.save
    assert_equal(0, obs.errors.length, 'Could not save even when logged in.')

    # Make sure our local time is the same after being saved then retrieved
    # from database.  'Make sure the modified' timestamp also gets set to some
    # time between then and now.
    obs = Observation.last
    now1 = now.in_time_zone
    now2 = Time.now.in_time_zone
    assert_equal(now1.to_s, obs.created.to_s, '"created" got mangled.')
    assert(now1 <= obs.modified+1.second, '"modified" is too old.')
    assert(now2 >= obs.modified-1.second, '"modified" is too new.')

    # Now check the internal representation.  Should be UTC.
    obs = Observation.find(2)
    created = Time.utc(2006,5,12,17,20,0).in_time_zone
    assert_equal(created, obs.created, 'Time in database is wrong.')
  end

  # --------------------------------------------------------
  #  Make sure update_view_stats is working as advertised.
  # --------------------------------------------------------

  def test_update_view_stats
    User.current = @rolf
    obs      = Observation.find(2)
    image    = obs.images.first
    comment  = obs.comments.first
    interest = obs.interests.first
    location = obs.location
    loc_desc = obs.location.description
    name     = obs.name
    name_desc= obs.name.description
    naming   = obs.namings.first
    user     = obs.user

    obs_attrs      = obs.attributes.dup
    image_attrs    = image.attributes.dup
    comment_attrs  = comment.attributes.dup
    interest_attrs = interest.attributes.dup
    location_attrs = location.attributes.dup
    assert_nil(loc_desc)
    name_attrs     = name.attributes.dup
    assert_nil(name_desc)
    naming_attrs   = naming.attributes.dup
    user_attrs     = user.attributes.dup

    num_past_names     = Name::Version.count
    num_past_name_descs= NameDescription::Version.count
    num_past_locations = Location::Version.count
    num_past_loc_descs = LocationDescription::Version.count
    num_transactions   = Transaction.count

    for attrs, obj in [
      [ obs_attrs,      obs      ],
      [ image_attrs,    image    ],
      [ comment_attrs,  comment  ],
      [ interest_attrs, interest ],
      [ location_attrs, location ],
      [ name_attrs,     name     ],
      [ naming_attrs,   naming   ],
      [ user_attrs,     user     ],
    ]
      obj.update_view_stats
      assert_same_but_view_stats(attrs, obj.reload.attributes,
                                 "#{obj.class}#update_view_stats screwed up: ")
    end

    assert_equal(num_past_names     + 0, Name::Version.count)
    assert_equal(num_past_name_descs+ 0, NameDescription::Version.count)
    assert_equal(num_past_locations + 0, Location::Version.count)
    assert_equal(num_past_loc_descs + 0, LocationDescription::Version.count)
    assert_equal(num_transactions   + 0, Transaction.count)
  end

  # -------------------------------------------------------------------
  #  Test the auto-rss-log magic.  Make sure RssLog objects are being
  #  created and attached correctly, especially since we now keep a
  #  redundant rss_log_id in the owning objects.
  # -------------------------------------------------------------------

  def test_location_rss_log_life_cycle
    User.current = @rolf
    time = 1.minute.ago

    loc = Location.new(
      :name => 'Test Location',
      :north => 54,
      :south => 53,
      :west  => -101,
      :east  => -100,
      :high  => 100,
      :low   => 0
    )

    assert_nil(loc.rss_log)
    assert_save(loc)
    loc_id = loc.id
    assert_not_nil(rss_log = loc.rss_log)
    assert_equal(:location, rss_log.target_type)
    assert_equal(loc.id, loc.rss_log.location_id)
    assert_rss_log_lines(1, rss_log)
    assert_rss_log_has_tag(:log_location_created, rss_log)

    rss_log.update_attribute(:modified, time)
    loc.log(:test_message, :arg => 'val')
    rss_log.reload
    assert_rss_log_lines(2, rss_log)
    assert_rss_log_has_tag(:test_message, rss_log)
    assert(rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    loc.update_attribute(:display_name, 'New Location')
    rss_log.reload
    assert_rss_log_lines(3, rss_log)
    assert_rss_log_has_tag(:log_location_updated, rss_log)
    assert(rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    Location.first.merge(loc)
    rss_log.reload
    assert_rss_log_lines(4, rss_log)
    assert_rss_log_has_tag(:log_location_merged, rss_log)
    assert(rss_log.modified > time)
    assert_nil(Location.safe_find(loc_id))
    assert_equal(:location, rss_log.target_type)
  end

  def test_name_rss_log_life_cycle
    User.current = @rolf
    time = 1.minute.ago

    name = Name.new(
      :text_name    => 'Test',
      :search_name  => 'Test',
      :sort_name    => 'Test',
      :display_name => '**__Test__**',
      :rank         => :Genus,
      :author       => ''
    )

    assert_nil(name.rss_log)
    assert_save(name)
    name_id = name.id
    assert_nil(name.rss_log)

    name.log(:test_message, :arg => 'val')
    assert_not_nil(rss_log = name.rss_log)
    assert_equal(:name, rss_log.target_type)
    assert_equal(name.id, rss_log.name_id)
    assert_rss_log_lines(1, rss_log)
    assert_rss_log_has_tag(:test_message, rss_log)

    rss_log.update_attribute(:modified, time)
    name.update_attribute(:author, 'New Author')
    # This is normally done by ApplicationController#save_name.
    name.log(:log_name_updated, :user => @rolf.login, :touch => true)
    rss_log.reload
    assert_rss_log_lines(2, rss_log)
    assert_rss_log_has_tag(:log_name_updated, rss_log)
    assert(rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    Name.first.merge(name)
    rss_log.reload
    assert_rss_log_lines(3, rss_log)
    assert_rss_log_has_tag(:log_name_merged, rss_log)
    assert(rss_log.modified > time)
    assert_nil(Name.safe_find(name_id))
    assert_equal(:name, rss_log.target_type)
  end

  def test_observation_rss_log_life_cycle
    User.current = @rolf
    time = 1.minute.ago

    obs = Observation.new(
      :when    => Time.now,
      :where   => 'Anywhere',
      :name_id => 1
    )

    assert_nil(obs.rss_log)
    assert_save(obs)
    # This is normally done by ObserverController#create_observation.
    obs.log(:log_observation_created)
    obs_id = obs.id
    assert_not_nil(rss_log = obs.rss_log)
    assert_equal(:observation, rss_log.target_type)
    assert_equal(obs.id, rss_log.observation_id)
    assert_rss_log_lines(1, rss_log)
    assert_rss_log_has_tag(:log_observation_created, rss_log)

    rss_log.update_attribute(:modified, time)
    obs.log(:test_message, :arg => 'val')
    rss_log.reload
    assert_rss_log_lines(2, rss_log)
    assert_rss_log_has_tag(:test_message, rss_log)
    assert(rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    obs.update_attribute(:notes, 'New Notes')
    # This is normally done by ObserverController#edit_observation.
    obs.log(:log_observation_updated, :touch => true)
    rss_log.reload
    assert_rss_log_lines(3, rss_log)
    assert_rss_log_has_tag(:log_observation_updated, rss_log)
    assert(rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    obs.destroy
    rss_log.reload
    # (extra line for orphan title)
    assert_rss_log_lines(5, rss_log)
    assert_rss_log_has_tag(:log_observation_destroyed, rss_log)
    assert_in_delta(time, rss_log.modified, 1.second)
    assert_nil(Observation.safe_find(obs_id))
    assert_equal(:observation, rss_log.target_type)
  end

  def test_project_rss_log_life_cycle
    User.current = @rolf
    time = 1.minute.ago

    proj = Project.new(
      :title => 'New Project',
      :summary => 'Old Summary'
    )

    assert_nil(proj.rss_log)
    assert_save(proj)
    # Normally done by ProjectController#add_project.
    proj.log_create
    proj_id = proj.id
    assert_not_nil(rss_log = proj.rss_log)
    assert_equal(:project, rss_log.target_type)
    assert_equal(proj.id, rss_log.project_id)
    assert_rss_log_lines(1, rss_log)
    assert_rss_log_has_tag(:log_project_created, rss_log)

    rss_log.update_attribute(:modified, time)
    proj.log(:test_message, :arg => 'val')
    rss_log.reload
    assert_rss_log_lines(2, rss_log)
    assert_rss_log_has_tag(:test_message, proj)
    assert(proj.rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    proj.update_attribute(:summary, 'New Summary')
    # Normally done by ProjectController#edit_project.
    proj.log_update
    rss_log.reload
    assert_rss_log_lines(3, rss_log)
    assert_rss_log_has_tag(:log_project_updated, rss_log)
    assert(proj.rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    proj.destroy
    # Normally done by ProjectController#destroy_project.
    proj.log_destroy
    rss_log.reload
    # (extra line for orphan title)
    assert_rss_log_lines(5, rss_log)
    assert_rss_log_has_tag(:log_project_destroyed, rss_log)
    assert(proj.rss_log.modified > time)
    assert_nil(Project.safe_find(proj_id))
    assert_equal(:project, rss_log.target_type)
  end

  def test_species_list_rss_log_life_cycle
    User.current = @rolf
    time = 1.minute.ago

    spl = SpeciesList.new(
      :title => 'New List',
      :when => Time.now,
      :where => 'Anywhere'
    )

    assert_nil(spl.rss_log)
    assert_save(spl)
    # Normally done by SpeciesListController#create_species_list.
    spl.log(:log_species_list_created)
    spl_id = spl.id
    assert_not_nil(rss_log = spl.rss_log)
    assert_equal(:species_list, rss_log.target_type)
    assert_equal(spl.id, rss_log.species_list_id)
    assert_rss_log_lines(1, rss_log)
    assert_rss_log_has_tag(:log_species_list_created, rss_log)

    rss_log.update_attribute(:modified, time)
    spl.log(:test_message, :arg => 'val')
    rss_log.reload
    assert_rss_log_lines(2, rss_log)
    assert_rss_log_has_tag(:test_message, rss_log)
    assert(spl.rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    spl.update_attribute(:title, 'New Title')
    # Normally done by SpeciesListController#edit_species_list.
    spl.log(:log_species_list_updated)
    rss_log.reload
    assert_rss_log_lines(3, rss_log)
    assert_rss_log_has_tag(:log_species_list_updated, rss_log)
    assert(spl.rss_log.modified > time)

    rss_log.update_attribute(:modified, time)
    spl.destroy
    rss_log.reload
    # (extra line for orphan title)
    assert_rss_log_lines(5, rss_log)
    assert_rss_log_has_tag(:log_species_list_destroyed, rss_log)
    assert_in_delta(time, spl.rss_log.modified, 1.second)
    assert_nil(SpeciesList.safe_find(spl_id))
    assert_equal(:species_list, rss_log.target_type)
  end
end
