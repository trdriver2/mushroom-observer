# helpers for ShowName view,
# Also used in ShowNameInfo section of ShowObservation
module ShowNameHelper
  # string of links to Names of any other non-deprecated synonyms
  def show_obs_approved_syn_links(name)
    return unless !name.unknown? && !browser.bot?
    return if (approved_synonyms = name.other_approved_synonyms).blank?

    links = approved_synonyms.map {|n| name_link(n)}
    label = if name.deprecated
              :show_observation_preferred_names.t
            else
              :show_observation_alternative_names.t
            end

    label + ": " + content_tag(:span, links.safe_join(", "), class: :Data)
  end

  # array of lines for name and any accepted synonym, each line comprising
  # link to observations of a name and a count of those observations
  #  Macrolepiota rachodes (Vittadini) Singer (1)
  #  Chlorophyllum rachodes (Vittadini) Vellinga (96)
  #  Chlorophyllum rhacodes (Vittadini) Vellinga (63)
  def obss_by_syn_links(name)
    names = [name] + name.other_approved_synonyms
    names.each_with_object([]) do |nm, lines|
      query = Query.lookup(:Observation, :of_name, name: nm, by: :confidence)
      count = query.select_count
      next if count.zero?

      query.save
      lines << link_to(nm.display_name.t,
                       add_query_param({ controller: :observer,
                                         action: :index_observation },
                                         query)
                      ) + " (#{count})"
    end
  end

  # link to search for observations of this taxon (under any name)
  def taxon_observations(name)
    query = Query.lookup(:Observation, :of_name, name: name, by: :confidence,
                         synonyms: :all)
    count = query.select_count
    query.save
    link_to(:show_taxon_observations.t,
            add_query_param({ controller: :observer,
                            action: :index_observation }, query)
           ) + " (#{count})"
  end

  # link to a search for observations where this taxon was proposed
  # (but is not the consensus)
  def taxon_proposed(name)
    query = Query.lookup(:Observation, :of_name, name: name, by: :confidence,
                         synonyms: :all, nonconsensus: :exclusive)
    count = query.select_count
    return nil if count.zero?
    query.save
    link_to(:show_taxon_proposed.t,
            add_query_param({ controller: :observer,
                              action: :index_observation}, query)
           ) + " (#{count})"
  end

  # link to a search for observations where this name was proposed
  # (but this taxon is not the consensus)
  def name_proposed(name)
    query = Query.lookup(:Observation, :of_name, name: name, by: :confidence,
                         synonyms: :no, nonconsensus: :exclusive)
    count = query.select_count
    return nil if count.zero?
    query.save
    link_to(:show_name_proposed.t,
            add_query_param({ controller: :observer,
                              action: :index_observation}, query)
           ) + " (#{count})"
  end

  # link to a search for species of name's genus. Sample text:
  #   List of species in Amanita Pers. (1433)
  def show_obs_genera(name)
    return  unless (genus = name.genus)
    query = Query.lookup(:Name, :of_children, name: genus, all: true)
    count = query.select_count
    query.save if !browser.bot?
    return unless count > 1

    link_to(:show_consensus_list_of_species.t(name: genus.display_name.t),
            add_query_param({ controller: :name, action: :index_name },
                            query)
           ) + " (#{count})"
  end
end
