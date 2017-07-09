class API::DiscussionsController < API::RestfulController
  load_and_authorize_resource only: [:show, :mark_as_read, :dismiss, :move]
  load_resource only: [:create, :update, :star, :unstar, :set_volume]
  after_action :track_visit, only: :show
  include UsesDiscussionReaders
  include UsesPolls
  include UsesFullSerializer

  def index
    load_and_authorize(:group, optional: true)
    instantiate_collection { |collection| collection.sorted_by_importance }
    respond_with_collection
  end

  def dashboard
    raise CanCan::AccessDenied.new unless current_user.is_logged_in?
    instantiate_collection { |collection| collection_for_dashboard collection }
    respond_with_collection
  end

  def inbox
    raise CanCan::AccessDenied.new unless current_user.is_logged_in?
    instantiate_collection { |collection| collection_for_inbox collection }
    respond_with_collection
  end

  def move
    @event = service.move discussion: resource, params: params, actor: current_user
    respond_with_resource
  end

  def mark_as_read
    service.mark_as_read discussion: resource, params: params, actor: current_user
    respond_with_resource
  end

  def dismiss
    service.dismiss discussion: resource, params: params, actor: current_user
    respond_with_resource
  end

  def pin
    service.pin discussion: resource, actor: current_user
    respond_with_resource
  end

  def star
    update_reader starred: true
  end

  def unstar
    update_reader starred: false
  end

  def pin_reader
    update_reader reader_unpinned: false
  end

  def unpin_reader
    update_reader reader_unpinned: true
  end

  def set_volume
    update_reader volume: params[:volume]
  end

  private

  def track_visit
    VisitService.record(group: resource.group, visit: current_visit, user: current_user)
  end

  def accessible_records
    Queries::VisibleDiscussions.new(user: current_user, group_ids: @group && @group.id_and_subgroup_ids)
  end

  def update_reader(params = {})
    service.update_reader discussion: load_resource, params: params, actor: current_user
    respond_with_resource
  end

  def collection_for_dashboard(collection, filter: params[:filter])
    case filter
    when 'show_participating' then collection.not_muted.participating.sorted_by_importance
    when 'show_muted'         then collection.muted.sorted_by_latest_activity
    else                           collection.not_muted.sorted_by_importance
    end
  end

  def collection_for_inbox(collection)
    collection.not_muted.unread.sorted_by_latest_activity
  end

end
