# MarkUs mailer for notifications.
class NotificationMailer < ApplicationMailer
  default from: 'noreply@markus.com'
  def release_email
    @user = params[:user]
    @grouping = params[:grouping]
    mail(to: @user.email, subject: default_i18n_subject(course: @grouping.course.name,
                                                        assignment: @grouping.assignment.short_identifier))
  end

  def release_spreadsheet_email
    @form = params[:form]
    @student = params[:student]
    @course = params[:course]
    mail(to: @student.role.email, subject: default_i18n_subject(course: @course.name,
                                                                form: @form.short_identifier))
  end

  def grouping_invite_email
    @inviter = params[:inviter]
    @invited = params[:invited]
    @grouping = params[:grouping]
    mail(to: @invited.email, subject: default_i18n_subject(course: @grouping.course.name))
  end
end
