function createQueuedEmailService({ env, jobService, directEmailService }) {
  if (!env.jobs.enabled || !jobService) {
    return directEmailService;
  }

  return {
    async sendVerificationCode(payload) {
      await jobService.enqueue({
        type: "email.sendVerificationCode",
        payload
      });
    },
    async sendPasswordResetCode(payload) {
      await jobService.enqueue({
        type: "email.sendPasswordResetCode",
        payload
      });
    }
  };
}

module.exports = { createQueuedEmailService };
