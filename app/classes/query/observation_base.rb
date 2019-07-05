# frozen_string_literal: true

# methods for initializing Quert's for Observations
class Query::ObservationBase < Query::Base
  include Query::Initializers::ContentFilters

  def model
    Observation
  end

  def parameter_declarations
    super.merge(
      # dates/times
      date?: [:date],
      created_at?: [:time],
      updated_at?: [:time],

      # strings/ lists
      include_subtaxa?: :boolean,
      include_synonyms?: :boolean,
      names?: [:string],

      comments_has?: :string,
      has_notes_fields?: [:string],
      herbaria?: [:string],
      herbarium_records?: [:string],
      locations?: [:string],
      notes_has?: :string,
      projects?: [:string],
      species_lists?: [:string],
      users?: [User],

      # numeric
      confidence?: [:float],
      east?: :float,
      north?: :float,
      south?: :float,
      west?: :float,

      # boolean
      has_comments?: { boolean: [true] },
      has_location?: :boolean,
      has_name?: :boolean,
      has_notes?: :boolean,
      has_sequences?: { boolean: [true] },
      is_collection_location?: :boolean
    ).merge(content_filter_parameter_declarations(Observation))
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("observations")
    add_date_condition("observations.when", params[:date])
    initialize_names_parameters
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_search_parameters
    add_range_condition("observations.vote_cache", params[:confidence])
    add_bounding_box_conditions_for_observations
    initialize_content_filters(Observation)
    super
  end

  def initialize_names_parameters
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:names], params[:include_synonyms],
                           params[:include_subtaxa])
    )
  end

  def initialize_association_parameters
    add_where_condition("observations", params[:locations])
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    initialize_projects_parameter
    initialize_species_lists_parameter
  end

  def initialize_herbaria_parameter
    add_id_condition(
      "herbarium_records.herbarium_id",
      lookup_herbaria_by_name(params[:herbaria]),
      :herbarium_records_observations, :herbarium_records
    )
  end

  def initialize_herbarium_records_parameter
    add_id_condition(
      "herbarium_records_observations.herbarium_record_id",
      lookup_herbarium_records_by_name(params[:herbarium_records]),
      :herbarium_records_observations
    )
  end

  def initialize_projects_parameter
    add_id_condition(
      "observations_projects.project_id",
      lookup_projects_by_name(params[:projects]),
      :observations_projects
    )
  end

  def initialize_species_lists_parameter
    add_id_condition(
      "observations_species_lists.species_list_id",
      lookup_species_lists_by_name(params[:species_lists]),
      :observations_species_lists
    )
  end

  def initialize_boolean_parameters
    initialize_is_collection_location_parameter
    initialize_has_location_parameter
    initialize_has_name_parameter
    initialize_has_notes_parameter
    add_has_notes_fields_condition(params[:has_notes_fields])
    add_join(:comments) if params[:has_comments]
    add_join(:sequences) if params[:has_sequences]
  end

  def initialize_is_collection_location_parameter
    add_boolean_condition(
      "observations.is_collection_location IS TRUE",
      "observations.is_collection_location IS FALSE",
      params[:is_collection_location]
    )
  end

  def initialize_has_location_parameter
    add_boolean_condition(
      "observations.location_id IS NOT NULL",
      "observations.location_id IS NULL",
      params[:has_location]
    )
  end

  def initialize_has_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      "names.rank <= #{genus} or names.rank = #{group}",
      "names.rank > #{genus} and names.rank < #{group}",
      params[:has_name],
      :names
    )
  end

  def initialize_has_notes_parameter
    add_boolean_condition(
      "observations.notes != #{escape(Observation.no_notes_persisted)}",
      "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      params[:has_notes]
    )
  end

  def initialize_search_parameters
    add_search_condition(
      "observations.notes",
      params[:notes_has]
    )
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def add_join_to_locations!
    add_join(:locations!)
  end

  def default_order
    "date"
  end
end
