import express, { type Request, type Response } from 'express'

const app = express()
const { PORT = 3000 } = process.env

app.get('/', (_req: Request, res: Response) => {
  res.status(200).send('Hello, Flox!\n')
})

app.get('/ping', (_req: Request, res: Response) => {
  res.status(200).send('pong\n')
})

app.listen(PORT, () => {
  console.log(`Listening on port ${PORT}...`)
})
