# Policy for annotation categories controller.
class AnnotationCategoryPolicy < ApplicationPolicy
  default_rule :manage?
  alias_rule :find_annotation_text?, :index?, to: :read?

  def manage?
    check?(:manage_assessments?, role)
  end

  def read?
    check?(:instructor?) || check?(:ta?)
  end
end
