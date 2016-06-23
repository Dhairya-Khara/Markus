require 'set'

class UnableToRandomlyAssignGroupException < Exception
end

module RandomAssignHelper
  # Performs the random assignment, and stores them in the database.
  # - pr_assignment: The peer review assignment.
  # - num_groups_for_reviewers: How many PR's each group in reviewer_groups should have.
  def perform_random_assignment(pr_assignment, num_groups_for_reviewers)
    reviewer_groups_relation = pr_assignment.valid_groupings
    reviewee_groups_relation = pr_assignment.parent_assignment.valid_groupings
    @shuffled_reviewees = []
    @num_groups_for_reviewers = num_groups_for_reviewers
    @reviewer_ids_assigned_reviewee_ids_map = Hash.new { |h, k| h[k] = Set.new }
    @eligible_reviewers = []
    reviewer_groups_relation.each { |reviewer| @eligible_reviewers.push(reviewer) }

    generate_shuffled_reviewees(reviewer_groups_relation, reviewee_groups_relation)
    populate_from_existing_peer_reviews(pr_assignment)
    perform_assignments()
  end

  private
  # Make sure there's enough reviewee groups in the following list such that
  # we have enough repeats of 'reviewee_groups' that we can assign every
  # reviewer group at least 'num_groups_for_reviewers' groups.
  def generate_shuffled_reviewees(reviewer_groups, reviewee_groups)
    num_times_to_add_reviewee = (reviewer_groups.size.to_f * @num_groups_for_reviewers / reviewer_groups.size).ceil
    num_times_to_add_reviewee.times { @shuffled_reviewees += reviewee_groups }
    @shuffled_reviewees.shuffle()
  end

  # We need to get all the existing peer reviews for assignments so we can
  # skip some assignments if they exist.
  def populate_from_existing_peer_reviews(pr_assignment)
    pr_assignment.get_peer_reviews().each do |peer_review|
      @reviewer_ids_assigned_reviewee_ids_map[peer_review.reviewer.id].add(peer_review.reviewee.id)
    end
  end

  def perform_assignments
    shuffle_index = 0
    remove_ineligible_reviewers()

    # Keep looping while we have reviewers who need assignments. This will
    # become an empty list when we've ensured that each reviewer has at least
    # the amount of peer reviews we were told to assign.
    while @eligible_reviewers.any?
      @eligible_reviewers.each do |reviewer|
        # Note: This function will perform the swap (if an index swap is needed),
        # since we may have to look ahead and replace 'shuffle_index' with some
        # element further ahead.
        reviewee = get_next_reviewee_from_forward_search(reviewer, shuffle_index)

        # If we get back nil, that means there was no possible swaps we could
        # find from a forward search. Our last attempt is to look backwards to
        # the previous elements, find whoever is assigned to them, and try to
        # swap in the current element with one of their assignments whereby the
        # trade would make this group and that one work. If we find none, then
        # it's an error which should throw an exception.
        if reviewee.nil?
          assign_reviewee_backwards_or_throw(reviewer, shuffle_index)
        else
          add_peer_review_to_db_and_remember_assignment(reviewer, reviewee)
        end

        shuffle_index += 1
      end

      # Now that we can safely prune the list of groups that meet the required
      # number of peer reviews, and then start again if we have no pruned out
      # all the groups.
      remove_ineligible_reviewers()
    end
  end

  def remove_ineligible_reviewers
    @eligible_reviewers.delete_if do |reviewer|
      @reviewer_ids_assigned_reviewee_ids_map[reviewer.id].size >= @num_groups_for_reviewers
    end
  end

  def get_next_reviewee_from_forward_search(reviewer, shuffle_index)
    # First, check if the current index provided works.
    potential_reviewee = @shuffled_reviewees[shuffle_index]
    if eligible_to_be_assigned(reviewer, potential_reviewee)
      return potential_reviewee
    end

    # Since the index doesnt work, look at the next element until the end of
    # the list, and swap if we find a working group.
    ((shuffle_index + 1)...@shuffled_reviewees.size).each do |new_shuffle_index|
      potential_reviewee = @shuffled_reviewees[new_shuffle_index]
      if eligible_to_be_assigned(reviewer, potential_reviewee)
        swap_shuffled_indices(shuffle_index, new_shuffle_index)
        return potential_reviewee
      end
    end

    # Return nil if forward searching failed, which indicates that we will have
    # to do backward searching.
    nil
  end

  def eligible_to_be_assigned(reviewer, reviewee)
    # If they already have an assignment to the group, it's not viable.
    if @reviewer_ids_assigned_reviewee_ids_map.has_key?(reviewer.id) and
          @reviewer_ids_assigned_reviewee_ids_map[reviewer.id].member?(reviewee.id)
      return false
    end

    # Since they're not assigned, the returned boolean is if they don't share students.
    reviewer.does_not_share_any_students?(reviewee)
  end

  def swap_shuffled_indices(first_index, second_index)
    @shuffled_reviewees[first_index], @shuffled_reviewees[second_index] =
        @shuffled_reviewees[second_index], @shuffled_reviewees[first_index]
  end

  def assign_reviewee_backwards_or_throw(reviewer, shuffle_index)
    # TODO - Go from shuffle_index - 1 .. 0
      # TODO - Look up the group assigned for that element
      # TODO - Check if the group can swap that element for the current one without any problems
        # TODO - If so, delete from DB, assign the current to the old group, and assign the old PR to this one

    # If we cannot assign after all that, something is very wrong...
    raise UnableToRandomlyAssignGroupException
  end

  def add_peer_review_to_db_and_remember_assignment(reviewer, reviewee)
    result = reviewee.current_submission_used.get_latest_result
    PeerReview.create!(reviewer: reviewer, result: result)

    @reviewer_ids_assigned_reviewee_ids_map[reviewer.id].add(reviewee.id)
  end
end
