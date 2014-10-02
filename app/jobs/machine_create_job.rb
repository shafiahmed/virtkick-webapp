class MachineCreateJob < ActiveJob::Base
  queue_as :default

  def perform new_machine_id
    job_initalize new_machine_id

    step :create_machine do
      Infra::Machine.create @new_machine
    end

    step do
      machine = MetaMachine.new \
          hostname: @new_machine.hostname,
          user_id: @new_machine.user_id,
          libvirt_hypervisor_id: 1, # TODO
          libvirt_machine_name: @new_machine.hostname # TODO
      machine.save!

      @new_machine.update_attributes! \
          given_meta_machine_id: machine.id,
          finished: true,
          current_step: nil
    end
  end

  private
  def job_initalize new_machine_id
    @new_machine = NewMachine.find new_machine_id
  end

  def step step_name = nil
    @new_machine.update_attribute :current_step, step_name if step_name
    ret = yield
    @new_machine.update_attribute "step_#{step_name}", true if step_name
    ret
  rescue Exception => e
    message = e.respond_to?(:errors) ? e.errors.first : e.message
    @new_machine.update_attributes \
        error_message: message,
        current_step: nil,
        finished: true
    puts e.message
    puts e.backtrace.join "\n"
    raise
  end

  # TODO: doesn't work with ActiveJob. https://github.com/collectiveidea/delayed_job/issues/715
  def max_attempts
    1
  end
end
