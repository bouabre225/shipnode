import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Next.js ShipNode Example',
  description: 'Deployed with ShipNode',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
