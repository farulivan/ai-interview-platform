# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Portfolios::Generator do
  let(:session) { create(:session) }
  let(:gemini) { instance_double(Gemini::HttpClient) }

  before do
    create(:transcript_turn, session: session, speaker: 'ai', text: 'Tell me about a slow page you fixed.')
    create(:transcript_turn, session: session, speaker: 'candidate', text: 'I measured it first, then split the list.')
  end

  def generate(answer)
    allow(gemini).to receive(:generate_content).and_return(answer)
    described_class.new(session: session, gemini_client: gemini).call
  end

  it 'saves a skill the interview never reached as not assessed, not as L1' do
    create(:coverage_map, session: session, skill_label: 'React', state: 'covered', probe_count: 3)
    create(:coverage_map, session: session, skill_label: 'Leadership & Ownership', state: 'not_yet', probe_count: 0)

    portfolio = generate('configured_skills' => [
      { 'skill_label' => 'React', 'level' => 3, 'competency_summary' => 'Measures before fixing.' },
      { 'skill_label' => 'Leadership & Ownership', 'level' => 1, 'competency_summary' => 'Not evaluated.' }
    ])

    skills = portfolio.portfolio_skills.index_by(&:skill_label)
    expect(skills['React']).to have_attributes(status: 'assessed', ai_level: 3, ai_confidence: 'high')
    expect(skills['Leadership & Ownership']).to have_attributes(status: 'not_assessed', ai_level: nil,
                                                                competency_summary: nil)
    expect(portfolio.reload.generation_status).to eq('complete')
  end

  it 'never turns an odd level into a number' do
    create(:coverage_map, session: session, skill_label: 'React')

    skill = generate('configured_skills' => [{ 'skill_label' => 'React', 'level' => 'strong' }])
            .portfolio_skills.first

    expect(skill).to have_attributes(status: 'unavailable', ai_level: nil, raw_level: '"strong"')
  end

  it 'still reports a configured skill the model left out' do
    create(:coverage_map, session: session, skill_label: 'React')
    create(:coverage_map, session: session, skill_label: 'Testing')

    portfolio = generate('configured_skills' => [{ 'skill_label' => 'React', 'level' => 3 }])

    expect(portfolio.portfolio_skills.find_by(skill_label: 'Testing'))
      .to have_attributes(status: 'unavailable', ai_level: nil)
  end

  it 'fails the report when the answer has no list of skills' do
    create(:coverage_map, session: session, skill_label: 'React')

    expect { generate('skills' => []) }.to raise_error(Portfolios::SkillResolver::InvalidAnswer)
    expect(session.portfolio.reload.generation_status).to eq('failed')
  end
end
