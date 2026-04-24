// Netlify Serverless Function: generate-report
// Uses OpenRouter API for free LLM access
// API key stored in Netlify env vars - never exposed to frontend

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const SITE_URL = process.env.SITE_URL || 'https://your-site.netlify.app';
const SITE_NAME = 'Eli\'s Learning';

exports.handler = async (event, context) => {
  // Only allow POST
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  // Parse request body
  let requestBody;
  try {
    requestBody = JSON.parse(event.body);
  } catch (e) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Invalid JSON in request body' }),
    };
  }

  const { studentName, tone, gradeLevel, instrument, criteria } = requestBody;

  // Validate required fields
  if (!studentName || !tone) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Missing required fields: studentName, tone' }),
    };
  }

  // Validate tone
  const validTones = ['good', 'average', 'needs_improvement'];
  if (!validTones.includes(tone)) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Invalid tone. Must be: good, average, or needs_improvement' }),
    };
  }

  // Build tone-specific instructions
  const toneInstructions = {
    good: `Write an enthusiastic and positive progress report. Highlight the student's strengths, excellent progress, and areas where they excel. Emphasize their dedication, musical growth, and promising talent. Use encouraging language that celebrates their achievements. Mention specific positives like outstanding practice consistency, excellent technique development, remarkable progress in sight-reading, superior performance quality, and strong musical expression.`,
    average: `Write a balanced progress report that acknowledges steady progress while identifying specific areas for growth. Be constructive and supportive. Mention that the student is meeting expectations and has solid foundations, but should focus on consistency in practice, refining technique, and deepening musical understanding. Suggest specific areas to develop like rhythm accuracy, chord transitions, or ear training. Avoid being overly critical or overly praising.`,
    needs_improvement: `Write a caring but candid progress report that addresses significant gaps and concerns while maintaining a supportive tone. Be specific about what needs improvement - irregular practice habits, technique issues, lack of progress on specific goals. Express concern but also offer clear guidance on what the student should do to improve. Frame it as constructive feedback from a caring teacher who believes in the student's potential to do better with focused effort.`,
  };

  const toneInstruction = toneInstructions[tone] || toneInstructions.average;

  // Default criteria if not provided
  const defaultCriteria = [
    'fluency and technical accuracy',
    'chord transitions and voicings',
    'rhythm accuracy and timing',
    'posture and hand position',
    'sight-reading ability',
    'ear training and music theory understanding',
    'practice consistency and dedication',
    'stage presence and performance confidence',
    'musical expression and interpretation',
    'lesson attendance and punctuality',
  ];

  const criteriaList = criteria && criteria.length > 0 ? criteria : defaultCriteria;
  const criteriaText = criteriaList.map(c => `- ${c}`).join('\n');

  // Build the prompt
  const systemPrompt = `You are a professional music education report writer for a private music school. You write thoughtful, specific, and professional progress reports for students.

OUTPUT FORMAT: Return ONLY the report text in your response. No headers, no explanations, no meta-commentary. Just the report itself.

The report should be:
- 3-4 paragraphs long
- Written in formal but warm language
- Addressed to parents/guardians
- Reference specific musical criteria and behaviors
- Include specific observations a music teacher would make
- End with encouragement and next steps

MUSIC CRITERIA TO REFERENCE (pick relevant ones based on the student's level):
${criteriaText}

Student: ${studentName}
Instrument: ${instrument || 'Piano'}
Grade Level: ${gradeLevel || 'Not specified'}`;

  const userPrompt = `Please write a music progress report for ${studentName}. The overall tone should be: "${toneInstruction}"

Write the report now.`;

  try {
    // OpenRouter API call - uses free models like meta-llama-3.1-8b-instruct
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
        'HTTP-Referer': SITE_URL,
        'X-Title': SITE_NAME,
      },
      body: JSON.stringify({
        model: 'meta-llama/llama-3.1-8b-instruct', // Free model on OpenRouter
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        max_tokens: 1024,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error?.message || `OpenRouter API error: ${response.status}`);
    }

    const data = await response.json();
    const reportText = data.choices?.[0]?.message?.content || '';

    if (!reportText) {
      throw new Error('No content generated');
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        report: reportText,
        model: 'meta-llama/llama-3.1-8b-instruct',
        usage: data.usage,
      }),
    };
  } catch (error) {
    console.error('OpenRouter API error:', error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Failed to generate report',
        message: error.message,
      }),
    };
  }
};
