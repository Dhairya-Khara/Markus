module Admin
  # Main Admin policy class
  class MainAdminPolicy < ApplicationPolicy
    default_rule :manage?

    skip_pre_check :role_exists?
    pre_check :admin_user?

    def manage?
      real_user.admin_user?
    end

    def admin_user?
      allow! if real_user.admin_user?
    end
  end
end
